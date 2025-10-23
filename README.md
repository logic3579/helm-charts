[![Artifact Hub](https://img.shields.io/badge/Artifact%20Hub-repo-blue)](https://artifacthub.io/) [![Release Charts](https://github.com/logic3579/helm-charts/actions/workflows/release.yml/badge.svg?branch=main)](https://github.com/logic3579/helm-charts/actions/workflows/release.yml)

## Usage

### Build a Helm package

To create a helm chart

    helm create charts/my-chart

Check configuration for all charts

    helm lint charts/*

Package all helm chart into chart archive

    cd docs && helm package ../charts/*

### GitHub Pages example

[Helm](https://helm.sh) must be installed to use the charts. Please refer to
Helm's [documentation](https://helm.sh/docs/) to get started.

[GitHub Pages settings](https://github.com/logic3579/helm-charts/settings/pages), use branch gh-pages and folder docs.

Index and publish helm package

    # helm repo index ./charts --url https://yakir.top/helm-charts
    helm repo index ./charts --url https://logic3579.github.io/helm-charts
    git add -A
    git commit -m 'Update helm-charts index.yaml'
    git push origin

Once Helm has been set up correctly, add the repo as follows:

    # helm repo add my-repo https://yakir.top/helm-charts/
    helm repo add my-repo https://logic3579.github.io/helm-charts

If you had already added this repo earlier, run `helm repo update` to retrieve
the latest versions of the packages.
You can then run `helm search repo my-repo` to see the charts.

Install the my-app chart:

    helm install my-chart my-repo/my-chart

Uninstall the chart:

    helm uninstall my-chart

### GitLab Package registry

[GitLab](https://gitlab.com/) must be installed to use. Please refer to
GitLab's [documentation](https://docs.gitlab.com/ee/user/packages/helm_repository/) to get started.

Install helm cm-push plugin

    # https://github.com/chartmuseum/helm-push
    helm plugin install https://github.com/chartmuseum/helm-push

Authenticate to the Helm repository, get username and token from GitLab

Index and publish helm package

    helm repo add --username <username> --password <access_token> my-repo https://gitlab.example.com/api/v4/projects/<project_id>/packages/helm/stable
    helm cm-push mychart-0.1.0.tgz my-repo

Install the my-app chart:

    helm install my-chart my-repo/my-chart

Uninstall the chart:

    helm uninstall my-chart
