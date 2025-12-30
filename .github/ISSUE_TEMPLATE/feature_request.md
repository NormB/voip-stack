---
name: Feature Request
about: Suggest a new feature or enhancement
title: '[FEATURE] '
labels: enhancement
assignees: ''
---

## Feature Summary

A clear and concise description of the feature you'd like to see.

## Problem Statement

What problem does this feature solve? Why is it needed?

Example: "I'm always frustrated when..."

## Proposed Solution

Describe how you envision this feature working.

## Alternative Solutions

Have you considered alternative approaches? Describe them here.

## Use Cases

Describe specific scenarios where this feature would be valuable:

1. **Use Case 1**: [Description]
2. **Use Case 2**: [Description]
3. **Use Case 3**: [Description]

## Component(s) Affected

Which parts of the stack would this feature touch?

- [ ] OpenSIPS
- [ ] Kamailio
- [ ] Asterisk
- [ ] FreeSWITCH
- [ ] RTPEngine
- [ ] Vault integration
- [ ] Database schema
- [ ] Homer (SIP capture)
- [ ] Monitoring (Prometheus/Grafana)
- [ ] Ansible roles/playbooks
- [ ] Configuration templates
- [ ] Documentation
- [ ] Testing framework
- [ ] Other: ___________

## Phase Alignment

Which phase does this feature align with?

- [ ] Phase 1: Basic calling (Weeks 1-6)
- [ ] Phase 1.5: Kamailio integration (Weeks 7-8)
- [ ] Phase 2: HA and production features (Weeks 9-16)
- [ ] Phase 2.5: FreeSWITCH integration (Weeks 17-18)
- [ ] Phase 3: Advanced monitoring (Weeks 19-26)
- [ ] Phase 4: Production hardening (Weeks 27-32)
- [ ] Future/Not Yet Planned

## Implementation Complexity

Your estimate of implementation complexity:

- [ ] Low (few hours, minor changes)
- [ ] Medium (few days, moderate changes)
- [ ] High (week+, significant changes)
- [ ] Very High (major architectural change)

## Breaking Changes

Would this feature introduce breaking changes?

- [ ] Yes (explain below)
- [ ] No
- [ ] Unsure

If yes, describe what would break and how to mitigate:

## Configuration Example

If this feature requires configuration, provide an example:

```yaml
# Example Ansible variable
feature_enabled: true
feature_setting: "value"
```

```ini
# Example OpenSIPS config
modparam("new_module", "parameter", "value")
```

## Testing Considerations

How should this feature be tested?

- [ ] Unit tests
- [ ] Integration tests
- [ ] Functional tests (SIPp scenarios)
- [ ] Security tests
- [ ] Load tests
- [ ] Manual testing only

## Documentation Requirements

What documentation would need to be created/updated?

- [ ] Architecture documentation
- [ ] Installation guide
- [ ] Configuration guide
- [ ] Troubleshooting guide
- [ ] API documentation (if applicable)
- [ ] Examples

## Security Implications

Does this feature have security implications?

- [ ] Yes (describe below)
- [ ] No
- [ ] Unsure

If yes, describe security considerations:

## Performance Impact

Expected performance impact:

- [ ] Positive (improves performance)
- [ ] Neutral (no significant impact)
- [ ] Negative (may reduce performance)
- [ ] Unknown

## Dependencies

Does this feature depend on:

- External libraries: [list]
- New services: [list]
- Specific versions: [list]
- Other features: [list]

## Similar Features

Are there similar features in:

- OpenSIPS: [link to docs]
- Kamailio: [link to docs]
- Asterisk: [link to docs]
- FreeSWITCH: [link to docs]
- Other VoIP stacks: [examples]

## Additional Context

Add any other context, screenshots, diagrams, or links about the feature request here.

## Willingness to Contribute

Are you willing to contribute to implementing this feature?

- [ ] Yes, I can implement this
- [ ] Yes, I can help with testing
- [ ] Yes, I can help with documentation
- [ ] No, but I can provide feedback during development
- [ ] No, just suggesting

## Related Issues/PRs

Link any related issues or pull requests here.
