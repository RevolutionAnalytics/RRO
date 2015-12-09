/*
 *  R.app : a Cocoa front end to: "R A Computer Language for Statistical Data Analysis"
 *  
 *  R.app Copyright notes:
 *                     Copyright (C) 2004-5  The R Foundation
 *                     written by Stefano M. Iacus and Simon Urbanek
 *
 *                  
 *  R Copyright notes:
 *                     Copyright (C) 1995-1996   Robert Gentleman and Ross Ihaka
 *                     Copyright (C) 1998-2001   The R Development Core Team
 *                     Copyright (C) 2002-2004   The R Foundation
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  A copy of the GNU General Public License is available via WWW at
 *  http://www.gnu.org/copyleft/gpl.html.  You can also obtain it by
 *  writing to the Free Software Foundation, Inc., 59 Temple Place,
 *  Suite 330, Boston, MA  02111-1307  USA.
 *
 *  Created by Simon Urbanek on 12/5/04.
 */

// context menu tags
#define kShowHelpContextMenuItemTag 10001

#define backgColorKey @"Background Color"
#define inputColorKey @"Input Color"
#define selectionColorKey @"Selection Color"
#define outputColorKey @"Output Color"
#define stdoutColorKey @"Stdout Color"
#define stderrColorKey @"Stderr Color"
#define promptColorKey @"Prompt Color"
#define rootColorKey   @"Root Color"

#define normalRdSyntaxColorKey @"Normal RdSyntax Color"
#define sectionRdSyntaxColorKey @"Section RdSyntax Color"
#define macroArgRdSyntaxColorKey @"MacroArg RdSyntax Color"
#define macroGenRdSyntaxColorKey @"MacroGen RdSyntax Color"
#define commentRdSyntaxColorKey @"Comment RdSyntax Color"
#define directiveRdSyntaxColorKey @"Directive RdSyntax Color"

#define normalSyntaxColorKey @"Normal Syntax Color"
#define stringSyntaxColorKey @"String Syntax Color"
#define numberSyntaxColorKey @"Number Syntax Color"
#define keywordSyntaxColorKey @"Keyword Syntax Color"
#define commentSyntaxColorKey @"Comment Syntax Color"
#define identifierSyntaxColorKey @"Identifier Syntax Color"
#define editorCursorColorKey @"RScriptEditorCursorColor"
#define editorBackgroundColorKey @"RScriptEditorBackgroundColor"
#define editorCurrentLineBackgroundColorKey @"RScriptEditorHighlightCurrentLineColor"
#define editorSelectionBackgroundColorKey @"RScriptEditorSelectionColor"

#define initialWorkingDirectoryKey @"Working directory"
#define lastUsedFileEncoding @"LastUsedFileEncoding"
#define usedFileEncodings @"UsedFileEncodings"

#define RScriptEditorFormatWidthCutoff  @"RScriptEditorFormatWidthCutoff"

#define FontSizeKey    @"Console Font Size"
#define RScriptEditorTabWidth    @"R Script Editor tab width"
#define RScriptEditorDefaultFont    @"R Script Editor default font"
#define RConsoleDefaultFont    @"R Console default font"
#define internalOrExternalKey  @"Use Internal Editor"
#define indentNewLines  @"RScriptEditorIndentNewLines"
#define indentNewLineAfterSimpleClause  @"RScriptEditorIndentNewLineAfterSimpleClause"
#define highlightCurrentLine  @"RScriptEditorHighlightCurrentLine"
#define showSyntaxColoringKey  @"Show syntax coloring"
#define showBraceHighlightingKey  @"Show brace highlighting"
#define highlightIntervalKey  @"Highlight interval"
#define HighlightIntervalKey  @"RScriptBraceHighlightInterval"
#define showLineNumbersKey  @"Show line numbers"
#define externalEditorNameKey  @"External Editor Name"
#define appOrCommandKey  @"Is it a .app or a command"
#define editOrSourceKey  @"Edit or source in file"
#define miscRAquaLibPathKey @"Append RAqua libs to R_LIBS"
#define enableLineWrappingKey @"Enable line wrapping if TRUE"
#define lineFragmentPaddingWidthKey @"Line fragment padding in editor"
#define lineNumberGutterWidthKey @"Line number gutter width"
#define importOnStartupKey @"Import history file on startup if TRUE"
#define enforceInitialWorkingDirectoryKey @"Enforce initial wd on startup"
#define historyFileNamePathKey @"History file path used for R type history files"
#define maxHistoryEntriesKey @"Max number of history entries"
#define removeDuplicateHistoryEntriesKey @"Remove duplicate history entries"
#define cleanupHistoryEntriesKey @"Cleanup history entries"
#define stripCommentsFromHistoryEntriesKey @"Strip comment history entries"
#define defaultCRANmirrorURLKey @"default.CRAN.mirror.URL"
#define stopAskingAboutDefaultMirrorSavingKey @"default.CRAN.mirror.save.dontask"

#define useQuartzPrefPaneSettingsKey @"Use QuartzPrefPane values"
#define quartzPrefPaneWidthKey @"QuartzPrefPane width"
#define quartzPrefPaneHeightKey @"QuartzPrefPane height"
#define quartzPrefPaneDPIKey @"QuartzPrefPane DPI"
#define quartzPrefPaneLocationKey @"QuartzPrefPane location"
#define quartzPrefPaneLocationIntKey @"QuartzPrefPane location as an integer"
#define quartzPrefPaneFontKey @"QuartzPrefPane font"
#define quartzPrefPaneFontSizeKey @"QuartzPrefPane fontsize"

#define kEditorAutosaveKey @"autosave.scripts"

#define prefShowArgsHints @"Show function args hints"

#define saveOnExitKey @"save.on.exit"

#define kAutoCloseBrackets @"auto.close.parens"

#define kExternalHelp @"use.external.help"

// defaults

#define kDefaultHistoryFile @".Rapp.history"

// NSString runBash constants
#define kBASHFileInternalexecutionUUID @"bashexeUUID"
#define kBASHTaskOutputFilePath  @"/tmp/R_BASH_OUTPUT"
#define kBASHTaskScriptCommandFilePath @"/tmp/R_BASH_SCRIPT_COMMAND"
#define kBASHTaskShellVariableInputFilePath @"/tmp/R_BASH_INPUT"
#define kBASHTaskRedirectActionNone                 200
#define kBASHTaskRedirectActionReplaceSection       201
#define kBASHTaskRedirectActionReplaceContent       202
#define kBASHTaskRedirectActionInsertAsText         203
#define kBASHTaskRedirectActionInsertAsSnippet      204
#define kBASHTaskRedirectActionShowAsHTML           205
#define kBASHTaskRedirectActionShowAsTextTooltip    207
#define kBASHTaskRedirectActionShowAsHTMLTooltip    208
#define kBASHTaskRedirectActionLastCode             208
#define kBASHTaskShellVariableExitShowAsHTML           @"R_TASK_EXIT_SHOW_AS_HTML"
#define kBASHTaskShellVariableExitShowAsHTMLTooltip    @"R_TASK_EXIT_SHOW_AS_HTML_TOOLTIP"
#define kBASHTaskShellVariableExitInsertAsSnippet      @"R_TASK_EXIT_INSERT_AS_SNIPPET"
#define kBASHTaskShellVariableExitInsertAsText         @"R_TASK_EXIT_INSERT_AS_TEXT"
#define kBASHTaskShellVariableExitShowAsTextTooltip    @"R_TASK_EXIT_SHOW_AS_TEXT_TOOLTIP"
#define kBASHTaskShellVariableExitNone                 @"R_TASK_EXIT_NONE"
#define kBASHTaskShellVariableExitReplaceContent       @"R_TASK_EXIT_REPLACE_CONTENT"
#define kBASHTaskShellVariableExitReplaceSelection     @"R_TASK_EXIT_REPLACE_SELECTION"

// user defined actions and snippet support

#define kDragActionFolderName  @"DragActions"
#define kUserCommandFileName   @"command.sh"

#define kShellVarNameDraggedFilePath          @"R_DRAGGED_FILE_PATH"
#define kShellVarNameDraggedRelativeFilePath  @"R_DRAGGED_RELATIVE_FILE_PATH"
#define kShellVarNameCurrentLine              @"R_CURRENT_LINE"
#define kShellVarNameCurrentWord              @"R_CURRENT_WORD"
#define kShellVarNameSelectedText             @"R_SELECTED_TEXT"
#define kShellVarNameCommandPath              @"R_COMMAND_PATH"
#define kShellVarNameCurrentFilePath          @"R_FILE_PATH"
#define kShellVarNameCurrentSnippetIndex      @"R_CURRENT_SNIPPET_INDEX"



// other constants


#define iBackgroundColor 0
#define iInputColor      1
#define iOutputColor     2
#define iPromptColor     3
#define iStderrColor     4
#define iStdoutColor     5
#define iRootColor       6
#define iErrorColor      iStderrColor
#define iSelectionColor  7
