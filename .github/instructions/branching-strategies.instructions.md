# Git Branching Strategy

This document outlines the git branching strategy and workflow for Salesforce development projects to ensure code quality, proper deployment procedures, and collaborative development practices.

Before starting development, ensure you have the latest code from the `develop` branch and create your feature branches accordingly if applicable.

## Branch Types

### Main Branches

#### `main`

- **Purpose**: Production-ready code
- **Protection**: Protected branch with required reviews
- **Deployment**: Automatically deploys to production org
- **Merge Policy**: Only accepts merges from `hotfix/*` and `production/*` branches via pull requests

#### `staging`

- **Purpose**: Pre-production integration and UAT testing
- **Protection**: Protected branch with required reviews
- **Deployment**: Automatically deploys to UAT/staging environment
- **Merge Policy**: Accepts merges from `release/*` and `hotfix/*` branches via pull requests
- **Testing**: Full UAT and integration testing performed here

#### `develop`

- **Purpose**: Integration branch for features under development
- **Protection**: Protected branch with required reviews
- **Deployment**: Automatically deploys to development org
- **Merge Policy**: Accepts merges from `feature/*` and `hotfix/*` branches

### Supporting Branches

#### `feature/*`

- **Purpose**: New features or enhancements
- **Naming**: `feature/JIRA-123-short-description` or `feature/short-description`
- **Source**: Created from `develop`
- **Merge Target**: `develop`
- **Lifecycle**: Deleted after successful merge

#### `release/*`

- **Purpose**: Prepare for release and UAT testing
- **Naming**: `release/v1.2.0` or `release/sprint-23`
- **Source**: Created from `develop`
- **Merge Target**: `staging`
- **Lifecycle**: Deleted after successful deployment to production

#### `production/*`

- **Purpose**: Final production deployment preparation from staging
- **Naming**: `production/v1.2.0` or `production/release-name`
- **Source**: Created from `staging` after successful UAT
- **Merge Target**: `main`
- **Lifecycle**: Deleted after successful production deployment

#### `hotfix/*`

- **Purpose**: Critical fixes for production issues
- **Naming**: `hotfix/JIRA-456-critical-bug-fix`
- **Source**: Created from `main`
- **Merge Target**: `main`, `staging`, and `develop`
- **Lifecycle**: Deleted after successful fix

## Workflow Process

### Feature Development

1. **Create Feature Branch**

   ```bash
   git checkout develop
   git pull origin develop
   git checkout -b feature/JIRA-123-new-validation-rule
   ```

2. **Development and Testing**
   - Develop features in isolated scratch org or developer sandbox
   - Write unit tests (minimum 75% code coverage)
   - Test thoroughly before committing

3. **Commit and Push**

   ```bash
   git add .
   git commit -m "feat: add validation rule for opportunity amount"
   git push origin feature/JIRA-123-new-validation-rule
   ```

4. **Create Pull Request**
   - Create PR from feature branch to `develop`
   - Include detailed description and testing evidence
   - Request code review from team members

5. **Code Review and Merge**
   - Address review feedback
   - Merge to `develop` after approval
   - Delete feature branch

### Release Process

1. **Create Release Branch**

   ```bash
   git checkout develop
   git pull origin develop
   git checkout -b release/v1.2.0
   ```

2. **Initial Testing and Stabilization**
   - Deploy to development environment for initial validation
   - Fix any integration issues in release branch
   - Ensure all features are working together

3. **Deploy to Staging/UAT**

   ```bash
   # Create PR from release branch to staging
   git push origin release/v1.2.0
   # Create PR: release/v1.2.0 → staging
   ```

   - Merge release branch to `staging` after code review
   - Automatic deployment to UAT environment
   - Perform comprehensive UAT testing
   - Business stakeholder validation

4. **Create Production Branch**

   ```bash
   # After successful UAT, create production branch from staging
   git checkout staging
   git pull origin staging
   git checkout -b production/v1.2.0
   ```

5. **Production Deployment**

   ```bash
   # Create PR from production branch to main
   git push origin production/v1.2.0
   # Create PR: production/v1.2.0 → main
   ```

   - Create PR from `production/*` to `main`
   - Final production deployment approval
   - Deploy to production after approval
   - Tag the release: `git tag v1.2.0`

6. **Cleanup**
   - Delete release and production branches
   - Merge any necessary changes back to `develop`

### Hotfix Process

1. **Create Hotfix Branch**

   ```bash
   git checkout main
   git pull origin main
   git checkout -b hotfix/JIRA-456-fix-critical-bug
   ```

2. **Fix and Test**
   - Implement minimal fix for critical issue
   - Test thoroughly in production-like environment

3. **Emergency Deployment**

   ```bash
   # Create PR directly to main for critical fixes
   git push origin hotfix/JIRA-456-fix-critical-bug
   # Create PR: hotfix/JIRA-456-fix-critical-bug → main
   ```

4. **Merge Back**
   - Merge hotfix to `main` first
   - Merge hotfix changes to `staging` and `develop`
   - Delete hotfix branch

## Branch Protection Rules

### `main` Branch

- Require pull request reviews (minimum 2 reviewers)
- Require status checks to pass
- Require branches to be up to date before merging
- Restrict pushes to administrators only
- Require linear history
- **Only accepts merges from `hotfix/*` and `production/*` branches**

### `staging` Branch

- Require pull request reviews (minimum 2 reviewers)
- Require status checks to pass
- Require branches to be up to date before merging
- Require UAT sign-off before creating production branch
- Allow force pushes for administrators only
- Only accepts merges from `release/*` and `hotfix/*` branches

### `develop` Branch

- Require pull request reviews (minimum 1 reviewer)
- Require status checks to pass
- Require branches to be up to date before merging
- Allow force pushes for administrators only

## Environment Mapping

| Branch         | Environment    | Purpose                                               |
| -------------- | -------------- | ----------------------------------------------------- |
| `main`         | Production     | Live production environment                           |
| `staging`      | UAT/Staging    | User acceptance testing and pre-production validation |
| `develop`      | Development    | Feature integration and development testing           |
| `feature/*`    | Scratch Orgs   | Individual feature development                        |
| `production/*` | Pre-Production | Final production deployment preparation               |

## Commit Message Conventions

Follow [Conventional Commits](https://www.conventionalcommits.org/) specification:
