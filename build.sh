#!/bin/bash

set -e
function echogr {
	echo -e \\033[32m$@\\033[0m
}
function echoye {
	echo -e \\033[33m$@\\033[0m
}

echogr Generating hosts files.
mkdir -p output
if command -v git > /dev/null; then
	DATE=$(git show -s --format=%cd --date=short)
else
	echoye Git not found, using current date for the \"Last updated\" field.
	DATE=$(date +%Y-%m-%d)
fi
node src/generate.js "$PWD/data" $DATE "$PWD/output"

if [ "$TRAVIS" != "true" ]; then
	echoye Not running on Travis CI, deployment skipped.
elif [ "$TRAVIS_PULL_REQUEST" != "false" ]; then
	echoye Building for a pull request, deployment skipped.
elif [ "$TRAVIS_BRANCH" != "hosts-source" ]; then
	echoye Bulding for a branch other than \"hosts-source\", deployment skipped.
else
	echogr Starting deployment.

	echogr Importing SSH key.
	base64 -d <<< $SSH_KEY > ~/.ssh/id_rsa
	chmod 600 ~/.ssh/id_rsa
	eval $(ssh-agent -s)
	ssh-agent bash
        ssh-add

	echogr Cloning master branch.
	git clone git@github.com:$TRAVIS_REPO_SLUG master

	rm master/hosts-files/*
	cp output/* master/hosts-files/
	cd master
	if [ -n "$(git status --porcelain)" ]; then
		echogr Changes detected.

		echogr Configuring git.
		git config user.name $COMMIT_USER
		git config user.email $COMMIT_EMAIL
		git config push.default simple

		echogr Git configured.
		cat .git/config

		echogr Commiting changes.
		git add -A
		if [ "$(git log --oneline $TRAVIS_COMMIT_RANGE | wc -l)" == "1" ]; then
			echogr Changes are from a single commit.
			git show -s --format="%H %B" $TRAVIS_COMMIT > commit-msg.tmp
		else
			echogr Changes are from multiple commits.
			printf "Multiple commits from hosts-source.\n\n" > commit-msg.tmp
			git log --format="%H %B" $TRAVIS_COMMIT_RANGE >> commit-msg.tmp
		fi
		GIT_COMMITTER_DATE=$(git show -s --format="%cD" $TRAVIS_COMMIT) git commit -S -F commit-msg.tmp

		echogr Changes committed, pushing.
		git push
	else
		echogr No changes detected, deployment skipped.
	fi
fi
