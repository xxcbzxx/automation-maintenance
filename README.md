# n8n-enabler

> Secure, policy-driven infrastructure maintenance with GitOps, approvals, compliance monitoring, and n8n integration.

---

## Overview

n8n-enabler is a centralized maintenance orchestration platform designed to manage infrastructure operations safely across Linux servers, Docker hosts, Proxmox nodes, Kubernetes clusters, print servers, and other managed systems.

Unlike traditional automation platforms that permit arbitrary command execution, n8n-enabler enforces a policy-first execution model where all operations are defined, reviewed, approved, audited, and version-controlled.

The platform combines:

- Maintenance Automation
- GitOps
- Compliance Monitoring
- Change Management
- Approval Workflows
- n8n Integration
- Host Fleet Management

Into a single operational platform.

---

# Why n8n-enabler?

Most automation environments eventually suffer from:

- Configuration drift
- Undocumented commands
- Untracked shell access
- Inconsistent server maintenance
- Lack of approval controls
- Missing audit trails
- Forgotten operational procedures
- Environment-specific workarounds

Over time this results in:

- Risk
- Technical debt
- Operational uncertainty

n8n-enabler solves these problems by:

- Centralizing maintenance actions
- Enforcing policy validation
- Tracking infrastructure compliance
- Maintaining full audit history
- Storing all configurations in Git
- Integrating directly with n8n workflows

---

# Core Principles

## 1. No Arbitrary Shell Access

Traditional approach:

```bash
ssh server01 "apt update && apt upgrade -y"
```

n8n-enabler approach:

```bash
n8n-maintenance patch
```

All operations must be registered actions.

Direct command execution is prohibited.

---

## 2. Policy First

Every action is validated against:

```text
/etc/n8n-maintenance/policy.yml
```

before execution.

Example:

```yaml
policy:
  enabled: true

allowed_actions:

  check:
    enabled: true

  health:
    enabled: true

  patch:
    enabled: true
    approval_required: true

  reboot:
    enabled: false
```

No policy approval means no execution.

---

## 3. Git As Source Of Truth

Configuration is stored in Git.

Benefits:

- Version control
- Rollback capability
- Change visibility
- Team collaboration
- Auditing
- Disaster recovery

Every change becomes a documented event.

---

## 4. Test Before Change

Actions can be validated before execution.

Example:

```text
Action:
Patch

Host:
srv01

Mode:
Test
```

Result:

```text
Updates Available: 5

openssl
docker-ce
containerd
linux-image
curl
```

No modifications occur during testing.

---

## 5. Compliance Over Assumptions

Instead of assuming servers are configured correctly:

```text
"Hopefully all servers were updated."
```

n8n-enabler verifies:

```text
srv01      Compliant
srv02      Policy Drift
srv03      Agent Outdated
srv04      Missing Action
```

---

# Features

## Dashboard

The dashboard provides an operational overview of the environment.

### Summary Metrics

```text
Hosts Online
Compliant Hosts
Policy Mismatches
Pending Approvals
Failed Actions
Recent Changes
```

### Example

```text
Hosts Online: 15
Compliant: 13
Policy Drift: 2
Pending Approvals: 1
```

---

## Host Management

Maintain a centralized inventory of managed systems.

### Example Hosts

```text
srv01
srv02
srv03

proxmox

k3s-master
k3s-worker01

docker01
docker02

print-srv
```

### Host Attributes

```yaml
hostname:
ip_address:
environment:
tags:
agent_version:
policy_version:
policy_hash:
last_checkin:
status:
```

### Environment Support

- Linux
- Debian
- Ubuntu
- Docker Hosts
- Proxmox VE
- K3s
- Kubernetes
- Raspberry Pi
- Print Servers
- Virtual Machines

---

# Action Registry

Actions define what infrastructure operations are permitted.

## Examples

```text
check
health
patch
reboot
backup
verify-backup
docker-update
docker-prune
check-disk
restart-printing
update-agent
```

Every action contains:

```yaml
name:
description:
enabled:
approval_required:
host_tags:
test_command:
production_command:
rollback_steps:
documentation:
expected_output:
```

---

## Example Action

```yaml
name: patch

enabled: true

approval_required: true

allowed_hosts:
  - linux
  - docker

test_command: n8n-maintenance check

production_command: n8n-maintenance patch

expected_output:
  - STATUS=SUCCESS
```

---

# Test Execution Engine

The platform supports safe validation before execution.

## Validation Types

### String Validation

```text
STATUS=SUCCESS
```

### Regex Validation

```regex
UPDATE_COUNT=[0-9]+
```

### JSON Validation

```json
{
  "healthy": true
}
```

### YAML Validation

```yaml
status: healthy
```

---

## Example Workflow

```text
User
  ↓
Select Host
  ↓
Select Action
  ↓
Run Test
  ↓
Validate Output
  ↓
Display Results
```

---

# Approval Workflows

High-risk operations require human approval.

## Actions Requiring Approval

Examples:

```text
patch
reboot
docker-update
docker-prune
reset-service
```

---

## Approval Process

```text
Request
  ↓
Pending Approval
  ↓
Review
  ↓
Approve / Deny
  ↓
Execute
```

---

## Approval Metadata

```yaml
requested_by:
requested_at:
approved_by:
approved_at:
expires_at:
comment:
```

---

# Audit Logging

Everything is auditable.

Nothing executes without being recorded.

---

## Audit Fields

```yaml
event_id:
timestamp:
user:
host:
action:
status:
approval:
result:
stdout:
stderr:
git_commit:
```

---

## Example Audit Event

```yaml
timestamp: 2026-10-26T12:00:00Z

user: david

host: srv01

action: patch

status: success
```

---

# Compliance Engine

The compliance engine continuously monitors infrastructure consistency.

---

## Compliance Checks

### Policy Drift

Detect hosts running outdated policies.

### Missing Actions

Detect servers missing required actions.

### Agent Version Drift

Identify outdated maintenance agents.

### Configuration Mismatch

Compare deployed and expected configurations.

### Failed Policies

Detect invalid policy states.

---

## Example Dashboard

```text
HOST           STATUS

srv01          COMPLIANT
srv02          POLICY DRIFT
srv03          ACTION MISSING
srv04          AGENT OUTDATED
```

---

# GitOps Integration

All configuration changes are managed through Git.

---

## Repository

```text
https://github.com/xxcbzxx/automation-maintenance
```

---

## Supported Operations

### Pull

Retrieve latest configurations.

### Commit

Record configuration changes.

### Push

Publish approved modifications.

### Diff

View configuration differences.

### Rollback

Restore previous versions.

### History

View change history.

---

## Example Workflow

```text
Web UI
  ↓
Modify Action
  ↓
Validate
  ↓
Commit
  ↓
Push To GitHub
  ↓
Deploy
```

---

# Configuration Management

The UI manages all YAML generation automatically.

Administrators should not edit YAML directly.

---

## policy.yml

Defines platform-wide execution rules.

### Example

```yaml
policy:
  enabled: true

allowed_actions:
  check:
    enabled: true

  health:
    enabled: true

  patch:
    enabled: true
    approval_required: true

  reboot:
    enabled: false
```

---

## hosts.yml

Defines managed infrastructure.

### Example

```yaml
hosts:

  - hostname: srv01
    tags:
      - docker

  - hostname: proxmox
    tags:
      - hypervisor
```

---

## actions.yml

Defines available actions.

### Example

```yaml
actions:

  - name: patch
    enabled: true

  - name: reboot
    enabled: false
```

---

## approvals.yml

Defines approval policies.

### Example

```yaml
approval_rules:

  patch:
    required: true

  reboot:
    required: true
```

---

## users.yml

Defines users and roles.

### Example

```yaml
users:

  - username: admin
    role: administrator

  - username: operator
    role: operator
```

---

# n8n Integration

n8n-enabler is designed to work with n8n workflows.

---

## Capabilities

n8n may:

- Request actions
- Trigger tests
- Submit approvals
- Query compliance
- Retrieve audit events
- Consume results

---

## Example Workflow

```text
n8n
  ↓
Request Patch
  ↓
Approval Required
  ↓
Approved
  ↓
Execute
  ↓
Return Result
```

---

## REST API

Example:

```http
POST /api/hosts/srv01/actions/patch
```

Response:

```json
{
  "status": "pending_approval"
}
```

---

# Security Model

Security is built around a Zero Trust approach.

---

## Security Features

### Role-Based Access Control

Roles:

```text
Administrator
Operator
Approver
Viewer
```

---

### Policy Enforcement

Actions are evaluated before execution.

---

### SSH Key Authentication

No password-based remote execution.

---

### API Authentication

Support for:

```text
JWT
API Tokens
OIDC
```

---

### GitHub Token Management

Secure repository integrations.

---

### Full Audit Trail

Every action is logged.

---

### Approval Gates

Destructive actions require approval.

---

# Architecture

```text
+--------------------------------------------------+
|                    WEB UI                        |
+--------------------------------------------------+
                        |
                        v
+--------------------------------------------------+
|                     API                          |
+--------------------------------------------------+
                        |
      +-----------------+-----------------+
      |                 |                 |
      v                 v                 v

+-----------+   +--------------+   +-------------+
|  Policy   |   |    Audit     |   |   GitOps    |
|  Engine   |   |    Engine    |   |   Engine    |
+-----------+   +--------------+   +-------------+

      |                 |                 |
      +-----------------+-----------------+
                        |
                        v

+--------------------------------------------------+
|               Host Agent Layer                   |
|              n8n-maintenance                     |
+--------------------------------------------------+
                        |
                        v

+--------------------------------------------------+
| Linux | Docker | Proxmox | K3s | Print Servers  |
+--------------------------------------------------+
```

---

# Technology Stack

## Frontend

```text
React
TypeScript
Vite
TailwindCSS
TanStack Query
```

---

## Backend

```text
Node.js
NestJS
Express
TypeScript
```

---

## Database

```text
PostgreSQL
```

---

## Cache

```text
Redis
```

---

## GitOps

```text
Git
GitHub
```

---

## Automation

```text
n8n
```

---

## Deployment

```text
Docker
Docker Compose
Kubernetes (Future)
```

---

# Directory Structure

```text
n8n-enabler/

├── frontend/
│   ├── dashboard/
│   ├── hosts/
│   ├── actions/
│   ├── approvals/
│   ├── audit/
│   └── compliance/
│
├── backend/
│   ├── api/
│   ├── auth/
│   ├── git/
│   ├── policy/
│   ├── approval/
│   ├── compliance/
│   ├── audit/
│   └── execution/
│
├── agent/
│   └── n8n-maintenance/
│
├── configs/
│   ├── policy.yml
│   ├── hosts.yml
│   ├── actions.yml
│   ├── approvals.yml
│   └── users.yml
│
├── deployments/
│
├── docs/
│
└── tests/
```

---

# Roadmap

## Phase 1

- Dashboard
- Host Inventory
- Action Registry
- Policy Management
- Test Execution

---

## Phase 2

- Audit Logging
- Approval Workflows
- GitHub Synchronization

---

## Phase 3

- Compliance Engine
- Policy Drift Detection
- Agent Health Monitoring

---

## Phase 4

- RBAC
- OIDC
- SSO
- Multi-Tenant Support

---

## Phase 5

- Fleet Management
- Desired State Reconciliation
- Automated Remediation
- Enterprise Policy Packs

---

# Project Goal

n8n-enabler exists to make infrastructure maintenance:

- Safe
- Repeatable
- Auditable
- Compliant
- Version Controlled

by replacing ad-hoc shell execution with policy-driven, GitOps-managed operations that integrate seamlessly with n8n and modern infrastructure workflows.
