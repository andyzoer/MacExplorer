# Personal enhancements

MacExplorer was created by [Sazzad Hossain](https://github.com/djad442) at [Binary Quest](https://github.com/binaryquest/MacExplorer). This branch contains [andyzoer’s](https://github.com/andyzoer) personal additions to that project, building on the multilingual edition.

Branch: [`andyzoer-personal-enhancements`](https://github.com/andyzoer/MacExplorer/tree/andyzoer-personal-enhancements). Base: `4e0a178` of the multilingual edition. The fork’s default `multilingual-localization` branch is maintained independently. Publishing this branch does not open a pull request against the original project.

## What changed

### Hover and selection feedback

- Files, folders, sidebar entries, toolbar buttons, column headers, and storage cards in **This Mac** respond to pointer hover.
- Hovering over file and storage items adds a background. Selected items have a background and an outline; hovering over a selected item retains the outline.
- Toolbar menus such as **Sort**, **View**, and **Search options** have the same 30-point height as the icon buttons.
- Toolbar hover has one current owner to avoid highlights remaining on several buttons. Enabled toggles retain their separate active state.
- File tooltips show already-loaded metadata: name, path, kind, dates, size for files, and tags. They do not recursively scan folders or calculate folder sizes.

### Editable address bar and recent folders

Click empty space in the address bar or the current folder’s breadcrumb to edit the path. The redundant pencil button has been removed. The editor fills the address bar’s height and uses a borderless native combo box without a blue focus ring. **⌘L** also starts editing. Ancestor breadcrumbs still navigate to their folders. The full path is selected when editing begins; Return navigates and Escape cancels.

The native drop-down lists the 20 most recently opened folders. History is deduplicated and persists between launches. The implementation fixes a focus transition that previously caused the editor to close immediately after a click.

### Rename in place

A slow second click on an already selected file or folder name opens an editor directly over its label. This works in Details, Content, and icon views. Normal fast double-clicks still open items, and dragging does not start rename. **F2**, the Rename toolbar action, and the Rename context-menu action also use the inline editor.

For files, the name stem is selected initially; folder names are selected in full. **Return** or clicking outside saves an edited name. Leaving an unchanged name performs no file operation. **Escape** discards edits. Invalid names remain in the editor with an error indication. Renames use the existing conflict-handling and Undo engine. Presentation changes cancel an editor whose item/view is being replaced.

Nested sidebar folders now use filled yellow folder icons instead of outline symbols; special locations retain their own icons.

### Configurable Create menu

The context menu and toolbar **New** button offer a **Create** menu. Right-clicking one folder creates inside that folder; right-clicking empty space creates inside the current folder.

- **Folder**, **Text Document (.txt)**, and native macOS **Alias** are available without Office or Adobe applications.
- Blank **DOCX**, **XLSX**, and **PPTX** documents are included. Entries appear when macOS registers a compatible application; Microsoft Office is not required.
- **PSD**, **AI**, and other formats use real templates imported from the user’s editor, rather than empty files with a changed extension.
- **Settings → Create** controls enabled formats, menu names, templates, the application used to open a new document, and optional opening after creation.
- Creation uses the existing file-operation engine for conflict handling and Undo.

See [Create menu details](../CREATE-MENU.md), including template locations and limitations.

### Eject mounted volumes

Eligible volumes have an **Eject** entry in the **This Mac** and sidebar context menus, plus an eject button beside the sidebar entry. The system/startup disk and ordinary folders are excluded. Ejection runs off the UI thread and does not force a busy disk to disconnect.

Disk images are identified through the system’s `hdiutil info -plist` output and detached as complete devices with `hdiutil detach`. This fixes an APFS image issue in the initial personal implementation: a volume disappeared while its backing image remained attached, preventing reopening. Other eligible volumes use the native NSWorkspace eject API. Storage lists refresh after the attempt; errors are reported instead of forcing the operation.

### Localization and installation updates

English remains the only built-in language. All 42 external language packs include the new Create and Eject strings, with 453 ordinary string keys per pack at this revision. Missing or invalid translations continue to fall back to English. Translations are machine-assisted with some manual terminology corrections and may be inaccurate; review by fluent speakers is welcome.

**Install Explorer.command** now supplements installed language packs with missing keys. Existing translations, custom keys, plural rules, and translator credits take precedence. UTF-8 `.strings` comments are retained; other property-list formats may be serialized as XML. Reinstalling the app therefore delivers new translations such as **Eject** without erasing personal edits. Existing values are intentionally not replaced, so corrections to an already-present translation require explicit replacement through **Settings → General → Install Language Packs…** or editing the file.

The installer uses the app’s noninteractive `--merge-language-packs SOURCE DESTINATION` mode before replacing the application. No Python installation is required. Restart Explorer after updating packs because catalogs are loaded once per launch.

## Build and install

Requires macOS 14+ and a Swift 6 toolchain from Xcode or the Command Line Tools:

```sh
git clone --branch andyzoer-personal-enhancements https://github.com/andyzoer/MacExplorer.git
cd MacExplorer
zsh scripts/build.sh
open build/Explorer.app
```

The build produces `build/Explorer.app` and `build/Localizations`. Source builds are locally signed and have automatic software updates disabled.

For installation from source, copy `build/Explorer.app` to `/Applications`, then install packs from `build/Localizations` using **Settings → General → Install Language Packs…**. When using a packaged personal DMG, quit Explorer and run **Install Explorer.command**. **Uninstall Explorer.command** moves the application and installed packs to Trash; it retains preferences. A branch push does not publish a DMG or create a GitHub release.

Language packs live in `~/Library/Application Support/Explorer/Localizations/`. Imported document templates live in `~/Library/Application Support/Explorer/File Templates/`. See the [localization guide](LOCALIZATION.md) for adding a language without recompiling.

## Validation and scope

The regression suite was run on macOS. A separate integration test completed three attach/eject/reopen cycles on the same disposable DMG, verified that no image attachment remained, and checked that its bytes were unchanged. Initial hover and selection rendering was checked in light and dark appearances. Office templates were parsed by document-reading libraries; manual opening in Microsoft Office and Adobe applications was not tested.

Run the standard suite with `zsh scripts/test.sh`. The opt-in disk-image test requires a dedicated disposable fixture and runs separately with `--filter diskImageCanBeReopenedAfterRepeatedEjection`; it never targets an arbitrary mounted disk.

These changes were made primarily for personal use. No commitment is made to ongoing maintenance or compatibility with future upstream releases. They are shared under the project’s existing MIT license, without proposing them to the original maintainer at this time.
