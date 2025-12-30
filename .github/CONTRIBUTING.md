# Contributing to voip-stack

Thank you for considering contributing to voip-stack! This project aims to provide a production-ready VoIP infrastructure stack, and contributions from the community help make it better.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [How Can I Contribute?](#how-can-i-contribute)
- [Development Setup](#development-setup)
- [Submitting Changes](#submitting-changes)
- [Coding Standards](#coding-standards)
- [Testing Guidelines](#testing-guidelines)
- [Documentation](#documentation)

## Code of Conduct

This project and everyone participating in it is governed by our [Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code.

## How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check existing issues to avoid duplicates. When creating a bug report, include:

- **Clear title and description**
- **Steps to reproduce** the issue
- **Expected behavior** vs. actual behavior
- **Environment details** (OS, VM specs, component versions)
- **Logs** (sanitized of any sensitive information)
- **Configuration** (sanitized)

Use the [bug report template](.github/ISSUE_TEMPLATE/bug_report.md).

### Suggesting Features

Feature suggestions are welcome! Please:

- **Check existing issues** to see if it's already proposed
- **Provide clear use case** and rationale
- **Consider phasing** (which phase does this fit into?)
- **Think about compatibility** with existing components

Use the [feature request template](.github/ISSUE_TEMPLATE/feature_request.md).

### Contributing Code

1. **Fork the repository**
2. **Create a feature branch** (`git checkout -b feature/amazing-feature`)
3. **Make your changes**
4. **Add tests** for new functionality
5. **Update documentation** as needed
6. **Ensure all tests pass**
7. **Commit with clear messages** (see [Commit Messages](#commit-messages))
8. **Push to your fork**
9. **Create a Pull Request**

## Development Setup

### Prerequisites

- **macOS** with Apple Silicon (M1/M2/M3/M4)
- **16GB+ RAM** recommended
- **libvirt/QEMU** virtualization installed
- **[devstack-core](https://github.com/NormB/devstack-core)** running (Vault, PostgreSQL, Redis, etc.)
- **Ansible** installed on host

### Initial Setup

```bash
# Clone your fork
git clone https://github.com/yourusername/voip-stack.git
cd voip-stack

# Copy environment template
cp .env.example .env

# Edit .env with your configuration
vim .env

# Ensure devstack-core is running
cd ~/devstack-core && ./devstack start --profile standard

# Create and start VMs with libvirt
cd ~/voip-stack/libvirt
./create-vms.sh create
./create-vms.sh start

# Provision VMs with Ansible
cd ~/voip-stack
./scripts/ansible-run.sh provision-vms
```

### Running Tests

```bash
# Run all Phase 1 tests
./tests/run-phase1-tests.sh

# Run specific test suites
cd tests/integration
./test-vault-integration.sh
./test-opensips-asterisk.sh

# Run SIPp scenarios
cd tests/sipp
./scripts/run-basic-call-test.sh
```

## Submitting Changes

### Pull Request Process

1. **Update documentation** for any user-facing changes
2. **Add/update tests** to cover your changes
3. **Ensure CI passes** (when Phase 4 CI/CD is implemented)
4. **Update CHANGELOG.md** with your changes
5. **Request review** from maintainers
6. **Address feedback** promptly

### Pull Request Checklist

- [ ] Code follows project style guidelines
- [ ] All tests pass
- [ ] Documentation updated
- [ ] CHANGELOG.md updated
- [ ] No sensitive data in commits (secrets, real IPs, etc.)
- [ ] Commit messages are clear and descriptive

## Coding Standards

### Ansible

- **Use fully qualified collection names** (e.g., `ansible.builtin.template`)
- **YAML**: 2-space indentation
- **Name all tasks** clearly
- **Use variables** from Vault for secrets
- **Tag tasks** appropriately (e.g., `tags: [opensips, config]`)
- **Include comments** for complex logic

Example:
```yaml
- name: Install OpenSIPS from official repository
  ansible.builtin.apt:
    name: opensips
    state: present
    update_cache: yes
  tags: [opensips, install]
```

### Shell Scripts

- **Use `#!/bin/bash`** shebang
- **Set error handling**: `set -euo pipefail`
- **Quote variables**: `"${VAR}"` not `$VAR`
- **Include usage function** for user-facing scripts
- **Add comments** explaining non-obvious logic

Example:
```bash
#!/bin/bash
set -euo pipefail

VAULT_ADDR="${VAULT_ADDR:-http://192.168.64.1:8200}"
```

### Configuration Files

- **Use Jinja2 templates** for dynamic configs
- **Comment sections** clearly
- **Use variables** for all environment-specific values
- **Include examples** in comments

### Commit Messages

Follow conventional commit format:

```
<type>: <subject>

<body>

<footer>
```

**Types**:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `refactor`: Code refactoring
- `test`: Adding/updating tests
- `chore`: Maintenance tasks

**Example**:
```
feat: Add Kamailio dispatcher failover support

- Implement dispatcher module configuration
- Add health checks for RTPEngine instances
- Configure automatic failover with ds_select_dst
- Add Prometheus metrics for dispatcher status

Closes #42
```

## Testing Guidelines

### Test Coverage Requirements

- **Integration tests**: Required for all new features
- **Functional tests**: Required for SIP call flows
- **Security tests**: Required for TLS/SRTP changes
- **Load tests**: Optional but encouraged

### Writing Tests

1. **Descriptive names**: `test-opensips-registration-with-auth.sh`
2. **Clear assertions**: Use explicit success/failure checks
3. **Cleanup**: Always clean up test resources
4. **Idempotent**: Tests should be repeatable
5. **Isolated**: Don't depend on other tests

Example:
```bash
#!/bin/bash
set -euo pipefail

test_name="OpenSIPS Registration with Authentication"

# Setup
echo "Running: ${test_name}"
extension="1001"
password="$(vault kv get -field=password secret/extensions/${extension})"

# Test
sipp -sf scenarios/register.xml \
     -s "${extension}" \
     -ap "${password}" \
     -m 1 \
     192.168.64.10:5060

# Verify
if [ $? -eq 0 ]; then
    echo "✓ ${test_name} passed"
    exit 0
else
    echo "✗ ${test_name} failed"
    exit 1
fi
```

## Documentation

### Documentation Standards

- **Markdown format** for all docs
- **Clear headings** and structure
- **Code examples** for all procedures
- **Link to related docs**
- **Keep updated** with code changes

### Required Documentation

When adding features, update:

- **README.md**: If user-facing feature
- **Architecture docs**: If architectural change
- **Installation guide**: If setup process changes
- **Troubleshooting**: If new issues might arise
- **CHANGELOG.md**: Always

### Writing Style

- **Be concise** but complete
- **Use examples** liberally
- **Explain why** not just how
- **Consider your audience** (varying skill levels)
- **Test instructions** yourself

## Questions?

- **Open an issue** for questions about contributing
- **Check existing issues** and pull requests first
- **Be patient**: Maintainers are volunteers

## Recognition

Contributors will be recognized in:
- **CHANGELOG.md** for significant contributions
- **README.md** contributors section (coming in Phase 2)
- **Release notes** for major features

Thank you for helping make voip-stack better!
