#!/bin/sh
#
# TODO: Add the possibility to specify maven arguments (like MVN_ARGS="-Pprofile1 -Darguments='-Dalt[…]'")



SELF=$(basename $0)

# The most important line in each script
set -e

# Check for the git command
command -v git >/dev/null || {
    echo "$SELF: git command not found." 1>&2
    exit 1
}
# Check for the mvn command (maven)
command -v mvn >/dev/null || {
    echo "$SELF: mvn command not found." 1>&2
    exit 1
}

get_release_branch() {
    echo "release/$1"
}

create_release_branch() {
    echo -n "Creating release branch... "
    RELEASE_BRANCH=$(get_release_branch $1)
    echo "$RELEASE_BRANCH"
    create_branch=$(git checkout -b ${RELEASE_BRANCH} master 2>&1)
}

remove_release_branch() {
    echo -n "Removing release branch... "
    RELEASE_BRANCH=$(get_release_branch $1)
    echo "$RELEASE_BRANCH"
    remove_branch=$(git branch -D ${RELEASE_BRANCH} 2>&1)
}

mvn_release() {
    echo "Using maven-release-plugin... "
    mvn $MVN_ARGS -B release:prepare -DdevelopmentVersion=$1 -DreleaseVersion=$2
    echo "'mvn -B release:prepare' "
    mvn $MVN_ARGS release:perform -Dgoals=install
    echo "'mvn release:perform'"
}

# Merging the content of release branch to develop
merging_to_develop() {
    echo -n "Merging back to develop... "
    RELEASE_BRANCH=$(get_release_branch $1)
    git_co_develop=$(git checkout develop 2>&1)
    git_merge=$(git merge --no-ff ${RELEASE_BRANCH}  -m "[release-plugin] Merge ${RELEASE_BRANCH} into develop" 2>&1)
    echo "done"
}

# Rewind 1 commit (tag)
# Merge master in release_branch with ours strategy (we have the sure one)
# Merge back release_branch to master
merging_to_master() {
    echo -n "Merging back to master... "
    RELEASE_BRANCH=$(get_release_branch $1)
    git_co_release_branch=$(git checkout ${RELEASE_BRANCH} 2>&1)
    git_resete_release_branch=$(git reset --hard HEAD~1 2>&1)
    git_co_master=$(git checkout master 2>&1)
    # We make the assumption "theirs" is the best
    git_merge=$(git merge --no-ff ${RELEASE_BRANCH} -m "[release-plugin] Merge ${RELEASE_BRANCH} into master" 2>&1)
    echo "done"
}


display_usage (){
    echo -e "\nUsage:\n$0 developmentVersion releaseVersion \n"
}

if [ $# -ne 2 ];then
  echo "$#"
  echo "Missing parameters"
  display_usage
  exit 1
fi 
# check whether user had supplied -h or --help . If yes display usage 
if [[ ( $# == "--help") ||  $# == "-h" ]];then 
  display_usage
  exit 0
fi

# First get the working directory
test -n "$MVN_ARGS" && {
    echo "Maven arguments provided : $MVN_ARGS."
}
echo -n "Detecting version number... "
if `git rev-parse 2>/dev/null`; then
    BRANCH_NAME=$(git symbolic-ref -q HEAD)
    BRANCH_NAME=${BRANCH_NAME##refs/heads/}
    WORKING_DIR=$(git rev-parse --show-toplevel)
    cd $WORKING_DIR
    NEXT_WORKING_VERSION="${1}"
    STABLE_VERSION="${2}"
    echo "$STABLE_VERSION"
    create_release_branch $STABLE_VERSION
    mvn_release $NEXT_WORKING_VERSION $STABLE_VERSION
    merging_to_develop $STABLE_VERSION
    merging_to_master $STABLE_VERSION
    remove_release_branch $STABLE_VERSION
    # Getting back to where we were
    git checkout $BRANCH_NAME
else
    echo "$SELF: you are not in a git directory"
    exit 2
fi
