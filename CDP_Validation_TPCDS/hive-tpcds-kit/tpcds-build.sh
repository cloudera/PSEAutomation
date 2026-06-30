# Copyright 2022 Cloudera, Inc. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#!/bin/sh

# Check for all the stuff I need to function.
for f in gcc javac; do
	which $f > /dev/null 2>&1
	if [ $? -ne 0 ]; then
		echo "Required program $f is missing. Please install or fix your path and try again."
		exit 1
	fi
done

# Check if Maven is installed and install it if not.
which mvn > /dev/null 2>&1
if [ $? -ne 0 ]; then
	SKIP=0
	if [ -e "apache-maven-3.9.6-bin.tar.gz" ]; then
		SIZE=`du -b apache-maven-3.9.6-bin.tar.gz | cut -f 1`
		if [ $SIZE -eq 5144659 ]; then
			SKIP=1
		fi
	fi
	if [ $SKIP -ne 1 ]; then
		echo "Maven not found, automatically installing it."
		curl -O https://downloads.apache.org/maven/maven-3/3.9.6/binaries/apache-maven-3.9.6-bin.tar.gz 2> /dev/null
		if [ $? -ne 0 ]; then
			echo "Failed to download Maven, check Internet connectivity and try again."
			exit 1
		fi
	fi
	tar -zxf apache-maven-3.9.6-bin.tar.gz > /dev/null
	CWD=$(pwd)
	export MAVEN_HOME="$CWD/apache-maven-3.9.6"
	export PATH=$PATH:$MAVEN_HOME/bin
fi

echo "Building TPC-DS Data Generator"
(cd tpcds-gen; make)
echo "TPC-DS Data Generator built. You can now use tpcds-gen.sh to generate data."
