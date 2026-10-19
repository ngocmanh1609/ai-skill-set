# UI check against the design

Run only when the PR changes UI code and a design link was found.

1. Fetch the frame with **D1** from the design adapter (a rendered screenshot, not a
   code export: it is cheaper and shows what you need).
2. Read the "UI tokens" section of `rules_file`. It maps design values to the project's
   tokens (text styles, colors, spacing units).
3. Compare the changed UI files against the frame for each item in `design.compare`
   (default: padding, gap/spacing, corner radius, text style and size, text color,
   background color). Name the token the code should use, not only the raw value.
4. Record each difference as a finding: dimension `ui`, severity `major` when it is
   visible at normal size, `minor` otherwise.

Say exactly what you compared. If the link covers only some of the changed screens,
name the frame you checked and list the others under "Not checked". One matching frame
must not make the whole PR look visually checked.

If a value in the screenshot is really ambiguous (for example, 12 vs 14 spacing), use the
adapter's fallback for exact values on that one node only.
