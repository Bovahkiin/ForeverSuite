# Release images

Upload the `.previews` folder and the updated `README.md` to the repository
**before creating the release tag**. WowUp Hub reads screenshots from the tagged
branch's `.previews` folder; attaching them only to the release is not equivalent.

| File | Use |
| --- | --- |
| `.previews/00-cover.png` | Brand cover; also embedded in the README |
| `.previews/01-in-game-interface.png` | Original, unedited in-game screenshot |
| `.previews/02-theme-artwork.png` | Blender comparison of the actual runtime theme textures |
| `.github/social-preview.jpg` | Repository social-preview image, under 1 MB |

For the social preview, open the repository's **Settings → General → Social
preview → Edit → Upload an image** and choose `.github/social-preview.jpg`.
Committing the file does not automatically set GitHub's social preview.

The gameplay screenshot was supplied during development and shows version
0.8.4. The following 0.8.5 patch fixes layout restoration without redesigning
the shown interface. The theme sheet is deliberately labeled as artwork.

The release ZIP remains focused on the addon and documentation. Gallery images
are repository media and are not installed into the game by the ZIP packager.

References:
- https://wowup.io/guide/wowup/hub
- https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/customizing-your-repositorys-social-media-preview
