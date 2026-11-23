import org.codehaus.groovy.control.CompilerConfiguration

abstract class PollTestPipeline extends Script {
    def pipeline(Closure body) {
        body()
        if (binding.hasVariable('pipelineError') && binding.pipelineError) {
            throw binding.pipelineError
        }
    }
    def agent(value) {}
    def environment(Closure body) {}
    def parameters(Closure body) {}
    def triggers(Closure body) {}
    def stages(Closure body) { body() }
    def steps(Closure body) { body() }
    def script(Closure body) { body() }
    def when(Closure body) {}
    def post(Closure body) { body() }
    def stage(String name, Closure body) {
        if (!(name in ['DRY RUN: Reload Jenkinsfile', 'Checkout'])) {
            try {
                body()
            } catch (RuntimeException e) {
                binding.pipelineError = e
                binding.currentBuild.result = 'FAILURE'
            }
        }
    }
    def success(Closure body) { if (!binding.hasVariable('pipelineError')) body() }
    def failure(Closure body) { if (binding.hasVariable('pipelineError')) body() }
    def always(Closure body) { body() }
    def string(Map parameter) { parameter }
    def booleanParam(Map parameter) { parameter }
    def password(Map parameter) { parameter }
    def echo(message) {}
    def error(message) { throw new RuntimeException(message.toString()) }
    def emailext(Map message) { binding.emails << message }
    def parallel(Map branches) { branches.values().each { it() } }
    def build(Map request) {
        def values = request.parameters.collectEntries { [(it.name): it.value] }
        def cloud = request.job.endsWith('aws') ? 'AWS' : 'AZURE'
        def operation = request.job.contains('build')
            ? (values.PROMOTE_SOURCE_TAG ? 'promote' : 'build')
            : values.ACTION
        binding.calls << [cloud: cloud, operation: operation, values: values]
        [result: binding.failures.contains("${cloud}:${operation}".toString()) ? 'FAILURE' : 'SUCCESS']
    }
}

def configuration = new CompilerConfiguration()
configuration.scriptBaseClass = PollTestPipeline.name

def runCase = { String file, String target, Set failures ->
    def calls = []
    def emails = []
    def binding = new Binding([
        any: 'any',
        env: [BUILD_NUMBER: '42', BUILD_URL: 'http://jenkins/job/42'],
        params: [
            CLOUD_TARGET: target, AWS_BUILD_BRANCH: 'aws-branch', AZURE_BUILD_BRANCH: 'azure-branch',
            AWS_REGION: 'us-west-2', AZURE_REGION: 'westus2', DOMAIN: 'example.com', HOSTEDZONEID: 'zone',
            DATALAKE_VERSION: '7.3.2', DELETE_DATAHUBS: true
        ],
        currentBuild: [result: null],
        JOB_NAME: 'pollscm-test',
        EMAIL_RECIPIENTS: 'test@example.com',
        BUILD_JOB_AWS: 'hol-automation-build-aws', BUILD_JOB_AZURE: 'hol-automation-build-azure',
        REMOTE_JOB_AWS: 'hol-automation-deploy-aws', REMOTE_JOB_AZURE: 'hol-automation-deploy-azure',
        calls: calls, failures: failures, emails: emails
    ])
    def failed = false
    try {
        new GroovyShell(this.class.classLoader, binding, configuration).evaluate(new File(file))
    } catch (RuntimeException e) {
        if (!e.message.startsWith('Candidate build, deploy, destroy, or promotion failed')) {
            throw e
        }
        failed = true
    }
    assert failed == !failures.isEmpty()
    assert binding.params.CLOUD_TARGET == target
    assert emails.size() == 1
    assert emails[0].subject.contains(failed ? 'failed' : 'promoted to latest')
    def selected = target == 'BOTH' ? ['AWS', 'AZURE'] : [target]
    assert calls.every { it.cloud in selected }
    selected.each { cloud ->
        def cloudCalls = calls.findAll { it.cloud == cloud }
        def expected = []
        for (def operation : ['build', 'provision', 'destroy', 'promote']) {
            expected << operation
            if (failures.contains("${cloud}:${operation}".toString())) {
                break
            }
        }
        assert cloudCalls*.operation == expected
        def candidate = cloudCalls[0].values.PRIMARY_TAG
        assert candidate.startsWith('candidate-')
        assert cloudCalls[0].values.PUSH_SECONDARY_TAG == false
        cloudCalls.findAll { it.operation in ['provision', 'destroy'] }.each {
            assert it.values.IMAGE_TAG == candidate
            assert it.values.BUILD_LOCAL_IMAGE == false
            assert it.values["${cloud}_REGION".toString()] == (cloud == 'AWS' ? 'us-west-2' : 'westus2')
        }
        cloudCalls.findAll { it.operation == 'promote' }.each {
            assert it.values.PRIMARY_TAG == 'latest'
            assert it.values.PROMOTE_SOURCE_TAG == candidate
        }
        def mailStatus = failures.find { it.startsWith("${cloud}:".toString()) }
        def displayCloud = cloud == 'AZURE' ? 'Azure' : cloud
        def rowStart = emails[0].body.indexOf("<td>${displayCloud}</td>")
        assert rowStart >= 0 : emails[0].body
        def rowEnd = emails[0].body.indexOf('</tr>', rowStart)
        def row = emails[0].body.substring(rowStart, rowEnd)
        def statuses = row.findAll(/<td>(SUCCESS|FAILED|NOT RUN)<\/td>/) {
            it[1]
        }
        if (mailStatus) {
            def failedOperation = mailStatus.split(':')[1]
            def operationIndex = ['build', 'provision', 'destroy', 'promote'].indexOf(failedOperation)
            assert statuses[operationIndex] == 'FAILED'
            assert statuses.drop(operationIndex + 1).every { it == 'NOT RUN' }
        } else {
            assert statuses == ['SUCCESS', 'SUCCESS', 'SUCCESS', 'SUCCESS']
        }
    }
}

['OnCloud/AWS/build/Jenkinsfile.PollSCM', 'OnCloud/Azure/build/Jenkinsfile.PollSCM'].each { file ->
    assert !new File(file).text.contains('env["${cloud.toUpperCase()}_')
    runCase(file, 'AWS', [] as Set)
    runCase(file, 'AZURE', [] as Set)
    runCase(file, 'BOTH', [] as Set)
    ['build', 'provision', 'destroy', 'promote'].each { operation ->
        runCase(file, 'BOTH', ["AWS:${operation}".toString()] as Set)
        runCase(file, 'BOTH', ["AZURE:${operation}".toString()] as Set)
    }
}
println 'PollSCM promotion scenarios passed'
