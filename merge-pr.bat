@echo off
setlocal

:: Check if PR number is provided
if "%~1"=="" (
    echo [ERROR] Usage: merge-pr-to-master.bat ^<PR_NUMBER^>
    exit /b 1
)

set "PR=%~1"
set "PR_BRANCH=pr-%PR%"
set "REMOTE_BRANCH=upstream/pr/%PR%"

:: Ensure we're in a Git repo
git rev-parse --is-inside-work-tree >nul 2>&1 || (
    echo [ERROR] This script must be run inside a Git repository.
    exit /b 1
)

:: Fetch just in case
echo [INFO] Fetching upstream PRs...
git fetch upstream

:: Create a local branch from upstream PR
echo [INFO] Creating local branch: %PR_BRANCH%
git show-ref --verify --quiet refs/remotes/%REMOTE_BRANCH% || (
    echo [ERROR] Pull request #%PR% does not exist in upstream.
    exit /b 1
)

git checkout -B "%PR_BRANCH%" "%REMOTE_BRANCH%" || (
    echo [ERROR] Failed to create local branch %PR_BRANCH%.
    exit /b 1
)

:: Switch to master in new fork
echo [INFO] Checking out master...
git checkout master || exit /b 1

:: Merge the PR
echo [INFO] Merging %PR_BRANCH% into master...
git merge --no-ff "%PR_BRANCH%" -m "Merge PR #%PR% from upstream" || (
    echo [ERROR] Merge failed. Resolve conflicts and commit manually.
    exit /b 1
)

:: Push master to new origin
echo [INFO] Pushing master to origin...
git push origin master || (
    echo [ERROR] Push failed.
    exit /b 1
)

echo [SUCCESS] Pull Request #%PR% merged and pushed to origin/master.

endlocal
exit /b 0
