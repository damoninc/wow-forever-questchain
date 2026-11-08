# QuestChain Adventure Guide Implementation Plan

> Run the steps in order and verify the installed addon against the files that passed the checks.

Use the approved Adventure Guide layout. Give the catalog the entire window body and keep Browse and Chain available as bottom tabs. Preserve the selected quest, catalog filters, results, and scroll position when switching pages.

- Add a Lua 5.1 smoke case for first open, full-width results, returning to a selected chain, and returning to the same position on a long zone list. Check that paging remains reachable while scrolled.
- Update `Window.lua` to render mutually exclusive catalog and chain pages, place category controls in one row, and align result metadata in columns. Use the warm, dark Adventure Guide palette and retain the native dropdown and scrollbar controls.
- Update `Core.lua` to pass result metadata and page numbers to the window. Keep the existing quest grouping, progress rules, and reward requests.
- Run the smoke case and all four fixture suites. Check the TOC files parse, verify the working diff, and copy the affected runtime files into the Forever installation.
