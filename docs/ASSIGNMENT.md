# Final Project — Original Assignment

> Verbatim assignment as given. This file records the original requirements the
> project is built against. See the root [`README.md`](../README.md) for how each
> item is implemented.

**Title:** Final
**Start date:** 2026-06-27 11:15:00
**Due date:** 2026-07-01 20:30:00

---

## Final Project Requirements

Your task is to finalize and improve your existing DevOps project developed throughout the semester.

You are NOT required to create a new project.

Your final project must be based on your previously submitted assignments. All previously implemented functionality must remain fully operational.

The goal of this project is to improve your existing DevOps solution by adding the topics covered during the final weeks of the course and making your project more secure, automated, reliable, and production-ready.

### Existing Functionality

The following features implemented in previous assignments must remain fully functional:

- Version Control (Git)
- Branching Strategy
- Continuous Integration (CI)
- Continuous Deployment (CD)
- Infrastructure as Code / Automation
- Docker / Docker Compose
- Monitoring
- Logging
- Observability
- Alerting
- Health Checks

Projects that remove or break previously implemented functionality will lose points.

---

## New Requirements

### 1. Environment Automation

Your project must support fully automated environment preparation.

Requirements:

- The application and all required services must be runnable locally or using Docker/Docker Compose.
- Environment preparation must be executable using a single command or a simple automated script.
- Configuration files and scripts should make the project reproducible on another machine without manual configuration.

### 2. Security Automation

Integrate security checks into your existing DevOps workflow.

Your implementation should include practical security improvements such as:

- Dependency vulnerability scanning
- Container image scanning (if containers are used)
- Secrets management or secrets scanning
- Security validation for Docker, Infrastructure as Code, or configuration files
- Security checks integrated into the CI/CD pipeline

You may use any suitable free tools.

### 3. Reliability Improvements

Improve the operational reliability of your project.

Examples include:

- Service health monitoring
- Rollback procedure
- Failure recovery automation
- Incident response documentation
- Service availability objectives
- Improved alerting strategy

Choose the improvements that best fit your project.

### 4. Automation Improvements

Review your existing automation pipeline and improve it where appropriate.

Examples include:

- Better deployment automation
- Improved CI/CD workflow
- Automated environment validation
- Additional pipeline stages
- Deployment verification
- Automatic post-deployment checks

### 5. Documentation

Update your README.md file.

The documentation should include:

- Project architecture
- Deployment workflow
- Environment setup instructions
- Security implementation
- Monitoring and logging overview
- Reliability improvements
- Screenshots demonstrating the implemented functionality

---

## Local Execution Requirement

All required functionality must be executable locally or using Docker/Docker Compose.

Projects must not require paid cloud services or commercial subscriptions for evaluation.

Only free and publicly available tools should be used.

---

## Submission Requirements

Students must submit:

- GitHub/GitLab repository link
- Updated README.md

The repository must contain everything required to run and evaluate the project.

---

## Important Notes

- The final project must extend your existing DevOps project.
- All previously implemented functionality must remain operational.
- Simply installing tools is not sufficient. Every required feature must be properly configured, integrated, and demonstrated.
- The project will be evaluated based on automation, security, reliability, documentation, and the overall quality of the implementation.
