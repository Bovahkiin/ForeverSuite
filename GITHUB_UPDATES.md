# Updating ForeverSuite on GitHub

Use your existing ForeverSuite project folder connected to Bovahkiin/ForeverSuite in GitHub Desktop.

## Update the source files

1. Put the updated addon files in your project folder.
2. Open GitHub Desktop and select ForeverSuite.
3. Review the changes.
4. Enter a short commit summary, such as **Update ForeverSuite to 1.0.4**.
5. Click **Commit to main**, then **Push origin**.

This updates the source on GitHub. The release workflow packages the download separately. Keep preview images in `.previews` and the `.toc` file at the root of the repository. Keep ZIP files, local work files, and test logs out of the commit.

## Build a downloadable release

1. Open [GitHub Actions](https://github.com/Bovahkiin/ForeverSuite/actions).
2. Select **Build ForeverSuite Release** in the sidebar.
3. Click **Run workflow**, leave **main** selected, and confirm.
4. Wait for the checks to pass. If a check fails, open the run to review the error.
5. Open the new draft under **Releases**.
6. Review the patch notes and the `ForeverSuite-VERSION-forever.zip` download.
7. Click **Publish release** when the update is ready.

To publish as soon as the checks pass, select **Publish immediately after the checks pass** when running the workflow. This publishes the release at the end of step 4.

The workflow tests the addon, packages the ZIP, and attaches the patch notes and checksum. It creates a release only for a new version number. Before running it, update the version in `ForeverSuite.toc` and `Core/Init.lua` and add the new patch notes at the top of `CHANGELOG.md`. GitHub Actions uses its built-in token to create the release.
