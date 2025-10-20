# Helm Repository Setup Guide

This guide explains how the public Helm repository is configured and how to maintain it.

## Overview

The Healenium Helm chart is automatically published to a public repository hosted on GitHub Pages at:
- **Repository URL**: `https://healenium.github.io/kubernetes`

Users can add it with:
```bash
helm repo add healenium https://healenium.github.io/kubernetes
```

## How It Works

### 1. GitHub Actions Workflow

The repository uses the [helm/chart-releaser-action](https://github.com/helm/chart-releaser-action) to automate the release process.

**Location**: `.github/workflows/release.yml`

**Triggers**: 
- Pushes to `master` branch
- When files change: `Chart.yaml`, `values.yaml`, `templates/**`, `requirements.yaml`

**What it does**:
1. Checks out the repository
2. Installs Helm
3. Prepares the chart directory structure
4. Packages the chart into a `.tgz` file
5. Creates a GitHub release with the chart package
6. Updates the `index.yaml` file in the `gh-pages` branch
7. Publishes to GitHub Pages

### 2. Chart Releaser Configuration

**Location**: `.github/cr.yaml`

Configuration for the chart-releaser tool:
```yaml
owner: healenium
git-repo: kubernetes
charts-repo-url: https://healenium.github.io/kubernetes
```

### 3. GitHub Pages

The `gh-pages` branch is automatically created and managed by the GitHub Actions workflow. It contains:
- `index.yaml` - Helm repository index file
- Chart packages (`.tgz` files) are stored as GitHub Releases

## Initial Setup (One-Time)

### Step 1: Enable GitHub Pages

1. Go to your repository settings: `https://github.com/healenium/kubernetes/settings/pages`
2. Under "Source", select:
   - **Branch**: `gh-pages`
   - **Folder**: `/ (root)`
3. Click **Save**

### Step 2: Set Up GitHub Actions Permissions

1. Go to repository settings: `https://github.com/healenium/kubernetes/settings/actions`
2. Under "Workflow permissions":
   - Select **"Read and write permissions"**
   - Check **"Allow GitHub Actions to create and approve pull requests"**
3. Click **Save**

### Step 3: Trigger First Release

To trigger the first release, you need to update the chart version:

1. Edit `Chart.yaml` and bump the version (e.g., from `0.1.0` to `0.1.1`)
2. Commit and push to master:
   ```bash
   git add Chart.yaml
   git commit -m "chore: bump chart version to trigger initial release"
   git push origin master
   ```
3. The GitHub Actions workflow will automatically run
4. After completion, check:
   - GitHub Releases: `https://github.com/healenium/kubernetes/releases`
   - GitHub Pages: `https://healenium.github.io/kubernetes/index.yaml`

## Releasing New Versions

### Automatic Release

To release a new version:

1. **Update the chart version** in `Chart.yaml`:
   ```yaml
   version: 0.2.0  # Increment this
   ```

2. **Update appVersion** (optional, but recommended):
   ```yaml
   appVersion: "0.2.0"
   ```

3. **Commit and push**:
   ```bash
   git add Chart.yaml
   git commit -m "chore: release version 0.2.0"
   git push origin master
   ```

4. The workflow will automatically:
   - Package the new chart version
   - Create a GitHub release
   - Update the Helm repository index

### Manual Release (if needed)

If you need to manually release a chart:

```bash
# Install chart-releaser
brew install chart-releaser

# Package the chart
mkdir -p .cr-release-packages
mkdir -p charts/healenium
cp -r Chart.yaml values.yaml requirements.yaml templates postgresql charts/healenium/
cr package charts/healenium

# Create GitHub release and upload chart
cr upload --owner healenium --git-repo kubernetes --token YOUR_GITHUB_TOKEN

# Update index.yaml
cr index --owner healenium --git-repo kubernetes --charts-repo https://healenium.github.io/kubernetes --push
```

## Versioning Guidelines

Follow [Semantic Versioning](https://semver.org/) for chart versions:

- **MAJOR** (1.0.0): Incompatible changes, breaking updates
- **MINOR** (0.1.0): New features, backward compatible
- **PATCH** (0.0.1): Bug fixes, backward compatible

Example:
- `0.1.0` → `0.1.1`: Bug fix
- `0.1.1` → `0.2.0`: New feature
- `0.2.0` → `1.0.0`: Breaking change

## Troubleshooting

### Workflow Fails

1. Check the Actions tab: `https://github.com/healenium/kubernetes/actions`
2. Review the logs for the failed step
3. Common issues:
   - **Permission denied**: Check GitHub Actions permissions in settings
   - **Chart already exists**: Version wasn't bumped in `Chart.yaml`
   - **Invalid chart**: Run `helm lint .` locally to check for errors

### Chart Not Showing Up

1. Verify the release was created: `https://github.com/healenium/kubernetes/releases`
2. Check `gh-pages` branch exists and has `index.yaml`
3. Verify GitHub Pages is enabled and deployed
4. Try updating the repo: `helm repo update healenium`

### Users Can't Find Chart

Users should run:
```bash
helm repo add healenium https://healenium.github.io/kubernetes
helm repo update
helm search repo healenium
```

If still not found:
- Check if `index.yaml` is accessible: `https://healenium.github.io/kubernetes/index.yaml`
- Wait a few minutes for GitHub Pages to deploy

## Testing

### Test Chart Locally

Before releasing:
```bash
# Lint the chart
helm lint .

# Template the chart (dry-run)
helm template healenium .

# Install locally
helm install healenium . --dry-run --debug
```

### Test Published Chart

After release:
```bash
# Add/update repo
helm repo add healenium https://healenium.github.io/kubernetes
helm repo update

# Search for charts
helm search repo healenium

# Show chart info
helm show chart healenium/healenium
helm show values healenium/healenium

# Install from repo
helm install test-release healenium/healenium --dry-run
```

## Best Practices

1. **Always test locally** before pushing changes
2. **Update Chart.yaml metadata** when making changes:
   - Bump `version` for every release
   - Update `appVersion` when container versions change
   - Document changes in commit messages
3. **Keep dependencies updated** in `requirements.yaml`
4. **Document breaking changes** in commit messages and release notes
5. **Test upgrades** from previous versions

## Resources

- [Helm Chart Releaser Action](https://github.com/helm/chart-releaser-action)
- [Helm Chart Best Practices](https://helm.sh/docs/chart_best_practices/)
- [Semantic Versioning](https://semver.org/)
- [GitHub Pages Documentation](https://docs.github.com/en/pages)

## Support

If you encounter issues:
1. Check the [GitHub Actions logs](https://github.com/healenium/kubernetes/actions)
2. Review this documentation
3. Open an issue at: `https://github.com/healenium/kubernetes/issues`

