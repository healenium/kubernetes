# Response Template for Issue #8

Copy and paste this response to https://github.com/healenium/kubernetes/issues/8 after completing the setup:

---

Hi @AndreiLepkovTR!

Thank you for the feature request! 🎉

We've implemented a public Helm repository. You can now install Healenium without cloning the repository:

### Quick Installation

```bash
# Add the Healenium Helm repository
helm repo add healenium https://healenium.github.io/kubernetes
helm repo update

# Install Healenium
helm install healenium healenium/healenium
```

### Additional Commands

```bash
# Search for available charts
helm search repo healenium

# Show chart information
helm show chart healenium/healenium
helm show values healenium/healenium

# Install with custom values
helm install healenium healenium/healenium -f my-values.yaml

# List available versions
helm search repo healenium -l

# Install specific version
helm install healenium healenium/healenium --version 0.1.0
```

### Resources

- **Repository URL**: https://healenium.github.io/kubernetes
- **Installation Guide**: [Quick Start](https://github.com/healenium/kubernetes#quick-start)
- **Chart Repository Index**: https://healenium.github.io/kubernetes/index.yaml

The updated installation instructions are now available in our [README](https://github.com/healenium/kubernetes#quick-start).

Feel free to try it out and let us know if you have any questions or feedback!

---

After posting this response, close the issue as completed.

