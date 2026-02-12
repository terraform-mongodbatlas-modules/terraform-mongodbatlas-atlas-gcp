"""Generate dev.tfvars for workspace tests."""

from pathlib import Path

import typer

app = typer.Typer()

WORKSPACE_DIR = Path(__file__).parent.parent.parent / "tests" / "workspace_gcp_examples"
DEV_TFVARS = WORKSPACE_DIR / "dev.tfvars"

DEFAULT_GCP_REGION = "us-east1"

_project_ids = """\
project_ids = {{
  encryption = "{project_id}"
}}
"""


@app.command()
def gcp(
    org_id: str = typer.Option(..., envvar="MONGODB_ATLAS_ORG_ID"),
    gcp_project_id: str = typer.Option(..., envvar=["GCP_PROJECT_ID", "GOOGLE_PROJECT"]),
    gcp_region: str = typer.Option(DEFAULT_GCP_REGION, envvar="GCP_REGION"),
    project_id: str = typer.Option(
        "",
        envvar="MONGODB_ATLAS_PROJECT_ID",
        help="Use the same project ID for all examples (for plan snapshot tests not for apply)",
    ),
) -> None:
    """Generate dev.tfvars from environment variables."""
    WORKSPACE_DIR.mkdir(parents=True, exist_ok=True)
    lines = [
        f'org_id = "{org_id}"',
        f'gcp_project_id = "{gcp_project_id}"',
    ]
    if gcp_region != DEFAULT_GCP_REGION:
        lines.append(f'gcp_region = "{gcp_region}"')
    else:
        typer.secho(f"GCP_REGION not set, using default {DEFAULT_GCP_REGION}", fg="yellow")
    if project_id:
        lines.append(_project_ids.format(project_id=project_id))
    else:
        typer.secho("MONGODB_ATLAS_PROJECT_ID not set, will create new projects", fg="yellow")
    content = "\n".join(lines) + "\n"
    DEV_TFVARS.write_text(content)
    typer.echo(f"Generated {DEV_TFVARS}")


@app.command()
def tfrc(plugin_dir: str) -> None:
    """Print dev.tfrc content for provider dev_overrides."""
    content = f'''provider_installation {{
  dev_overrides {{
    "mongodb/mongodbatlas" = "{plugin_dir}"
  }}
  direct {{}}
}}
'''
    print(content, end="")


if __name__ == "__main__":
    app()
