def extract(String logOutput) {
    def errorMessages = []
    def seen = new LinkedHashSet()
    def ignoredPatterns = [
        ~/fatal: detected dubious ownership in repository.*/
    ]

    def cleanLine = { String line ->
        return line.replaceAll('\\*+', ' ')
            .replaceAll('\\\\n', '\n')
            .replaceAll('\\\\"', '"')
            .replaceAll('\\s+', ' ')
            .trim()
    }

    def isIgnorableMessage = { String message ->
        def lower = message.toLowerCase()
        return lower.contains('already_exists') ||
            lower.contains('already assigned') ||
            lower.contains('is already assigned') ||
            (lower.contains('assignuserresourcerole') && lower.contains('already'))
    }

    def summarizeProvisionerError = { String message ->
        def lower = message.toLowerCase()

        if (lower.contains('saml providers count limit') || lower.contains('samlproviders count exceeds')) {
            return 'CDP SAML provider limit reached. Increase CDP_SAML_PROVIDER_LIMIT or remove unused SAML providers from the CDP tenant.'
        }
        if (lower.contains('iam group count limit') || lower.contains('group count exceeds the default quota')) {
            return 'CDP IAM group limit reached. Increase CDP_GROUP_LIMIT or remove unused CDP groups.'
        }
        if (lower.contains('iam users count limit') || lower.contains('user count exceeds the default quota')) {
            return 'CDP IAM user limit reached. Increase CDP_USER_LIMIT or remove unused CDP users.'
        }
        if (lower.contains('vpc limit has been reached')) {
            return 'AWS VPC limit reached in the selected region. Choose another region or delete unused VPCs.'
        }
        if (lower.contains('elastic ip')) {
            return 'AWS Elastic IP limit reached in the selected region. Release unused EIPs or choose another region.'
        }
        if (lower.contains('s3 bucket limit has been reached')) {
            return 'AWS S3 bucket limit reached. Delete unused buckets or request a quota increase.'
        }
        if (lower.contains('local_machine_ip cannot be') && lower.contains('0.0.0.0/0') && lower.contains('provision_caii')) {
            return 'When PROVISION_CAII is YES, LOCAL_MACHINE_IP cannot be 0.0.0.0/0. Use your Jenkins agent IP or Cloudera VPN: 208.127.31.110/32 or 208.127.31.11/32.'
        }
        if (lower.contains('not able to find config file')) {
            return 'Config file missing. Ensure configfile exists under /userconfig before running the job.'
        }
        if (lower.contains('infrastructure provisioning for') && lower.contains('not successful')) {
            return message
        }

        return message
    }

    def addMessage = { String message ->
        if (!message) {
            return
        }
        def normalized = cleanLine(message)
        if (!normalized || isIgnorableMessage(normalized)) {
            return
        }
        def summary = summarizeProvisionerError(normalized)
        if (seen.add(summary)) {
            errorMessages.add(summary)
        }
    }

    def extractJsonFields = { String payload ->
        [
            ~/"msg":\s*"((?:\\.|[^"\\])*)"/,
            ~/"fail_msg":\s*"((?:\\.|[^"\\])*)"/,
            ~/"stderr":\s*"((?:\\.|[^"\\])*)"/,
            ~/"error":\s*"((?:\\.|[^"\\])*)"/,
            ~/"violations":\s*"((?:\\.|[^"\\])*)"/
        ].each { pattern ->
            def matcher = pattern.matcher(payload)
            while (matcher.find()) {
                addMessage(matcher.group(1))
            }
        }

        def anErrorMatcher = ~/An error occurred:.+/
        def anError = anErrorMatcher.matcher(payload)
        if (anError.find()) {
            addMessage(anError.group())
        }
    }

    def isProvisionerErrorLine = { String line ->
        def trimmed = cleanLine(line)
        return trimmed.startsWith('FATAL:') ||
            trimmed.contains("Can't Continue:") ||
            trimmed.contains('exceeds the default quota') ||
            trimmed.contains('limit has been reached') ||
            (trimmed.contains('Infrastructure Provisioning For') && trimmed.contains('Not Successful'))
    }

    def lastTask = null
    logOutput.readLines().each { line ->
        if (line.contains('TASK [')) {
            lastTask = line.trim()
        }

        if (ignoredPatterns.any { line ==~ it }) {
            return
        }

        if (isProvisionerErrorLine(line)) {
            addMessage(line)
            return
        }

        if (line.contains('fatal:')) {
            def fatalMatcher = ~/fatal:\s*\[[^\]]+\]:\s*(?:FAILED!|UNREACHABLE!)\s*=>\s*(.+)$/
            def fatalMatch = fatalMatcher.matcher(line.trim())
            if (fatalMatch.find()) {
                def payload = fatalMatch.group(1)
                extractJsonFields(payload)
                if (errorMessages.isEmpty()) {
                    addMessage(lastTask ? "${lastTask} -> ${line.trim()}" : line.trim())
                }
            } else {
                addMessage(lastTask ? "${lastTask} -> ${line.trim()}" : line.trim())
            }
        }

        if (line.trim().startsWith('Error:') || line.contains('Error: Create') || line.contains('Error: Failed')) {
            if (!isIgnorableMessage(line)) {
                addMessage(line.trim())
            }
        }

        if (line.contains('An error occurred:') && !isIgnorableMessage(line)) {
            addMessage(line.trim())
        }

        if (line.contains('ERROR:') || line.contains('❌') || line.contains('Infrastructure Provisioning For')) {
            if (!isIgnorableMessage(line)) {
                addMessage(line.trim())
            }
        }

        if (line =~ /failed=[1-9]/ || line =~ /unreachable=[1-9]/) {
            addMessage("Ansible recap: ${line.trim()}")
        }
    }

    if (logOutput.contains('PLAY RECAP') && errorMessages.isEmpty()) {
        addMessage('Ansible playbook reported failures. See attached hol-provisioner log for details.')
    }

    return errorMessages
}

return this
