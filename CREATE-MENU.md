# Create menu (personal build)

Right-click empty space to create inside the current folder, or right-click one folder to create inside it. The toolbar **New** button offers the same menu for the current folder. The keyboard shortcut for a new folder is unchanged.

**Folder**, **Text Document (.txt)** and **Alias** are available without Office or Adobe software. An alias is a native macOS Finder alias pointing to a file or folder chosen in a file picker.

**Settings → Create** lets you enable/disable formats, change their menu titles, import document templates, choose an installed application, and optionally open a newly created document. By default creation does not launch applications. Names and conflicts use the existing file-operation dialogs; creation supports Undo through the existing copy/folder operation engine.

Blank DOCX, XLSX and PPTX packages are included. They appear when macOS registers a compatible application (not necessarily Microsoft Office). The system default handler is used unless you choose another application. Registration indicates file association, not a guarantee that an app can edit every feature of a format. These blank Office templates have no advanced formatting; replace them with your preferred empty documents if necessary.

For **Photoshop PSD** and **Illustrator AI**, save a blank document from Photoshop, Illustrator or your compatible editor, select the preset and click **Import Template…**. Explorer copies the real document; it never fabricates these proprietary formats by renaming an empty file. Select **Choose Application…** if macOS has no default handler or you prefer another editor.

**Add Format…** imports a regular document as a custom format. The template is copied into `~/Library/Application Support/Explorer/File Templates/`, so moving the original does not break creation. The imported file's extension determines the default new extension. Templates are copied byte for byte; their contents, including metadata or macros, remain intact. Use blank documents you trust. No scripts, shell commands or plug-ins are executed by the Create menu itself. Package documents (such as Pages bundles) are not currently supported as imported templates.

Preferences are stored locally in the app's UserDefaults. Changes apply to newly opened menus immediately, without restarting. Removing an entry does not delete files created with it; private imported template copies are retained. The Create menu strings are translated in all 42 external language packs, with English fallback for partial/custom packs. New translations are machine-assisted with terminology corrections and may still benefit from review by fluent speakers. Existing external language packs remain compatible. To update installed packs, extract the language-pack archive, open Settings → General → Install Language Packs…, choose its Localizations folder, and restart Explorer. Importing a pack replaces the installed pack for that language; retain a copy of any personal translation edits.

This personal build is published in the fork’s `personal-enhancements` branch and is not proposed upstream. Existing installation and language-pack locations are unchanged.

Development: `scripts/generate-document-templates.py` regenerates the bundled Office resources using python-docx, openpyxl and python-pptx. These are development tools, not application dependencies.
