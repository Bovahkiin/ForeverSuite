# Release images

The README and .previews gallery were refreshed for ForeverSuite 1.0.7.

| File | Use |
| --- | --- |
| `.previews/00-cover.png` | Project banner without a version number or theme count. |
| `.previews/01-control-center.png` | Real Control Center screenshot with pinned tools. |
| `.previews/02-all-tools.png` | Real All Tools screenshot with descriptions and pin controls. |
| `.previews/03-gear-planner.png` | Real Gear Planner screenshot. |

All gallery images are below 2 MB. The interface previews are cropped captures
from the actual addon. Keep full captures and any private chat outside the public
repository. Do not replace screenshots with generated interface mockups.

Commit gallery updates before the next release tag so distribution services can
read the updated media from that release's source. Updating the main branch does
not change an existing release tag or an image already uploaded to another service.

The release ZIP contains the addon and its user documentation. The .previews
gallery stays in the repository and is not installed in game.

GitHub's repository social-preview image is configured separately in repository
settings. Updating a README banner does not update that setting.
