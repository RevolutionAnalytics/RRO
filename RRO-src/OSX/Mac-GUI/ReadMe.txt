R app embedding R.

This is a true Cocoa application that embeds R.

The original code for embedding R in Cocoa is Simon's work.

You can consider this or any other derivative of this product a four-hand work of me and Simon.

R is started up with the option --gui=cocoa, this is temporarily needed because R_ProcessEvents is to be 
called from libR.dylib into the Cocoa app, and --gui=cocoa simply set a flag to conditionalize the 
R_ProcessEvents inside src/unix/aqua.c code. Once the aqua module will be declared "Defunct", --gui=aqua
would be enough

There are several tricks I did and there are several things to take into account. In sparse order, here they are:
1.  after awakefromnib, instead of blocking the main cocoa event loop directly calling  run_Rmainloop, a timer fires 
	once to call this function. At this point the menu bar is correctly built and the GUI can respond to the related 
	events.

2. to test x11/tcltk try the following:
	a)	run the X window server using the X11 icon int he toolbar
	b)	> library(tcltk)
	c)	> demo(tkdensity)

	it works! On the contrary AquaTclTk doesn't work at all, or at least is works as badly as it was for the Carbon RAqua.

Note: to build the R for Mac OS X FAQ manually use the following command from the shell
	makeinfo -D UseExternalXrefs --html --force --no-split RMacOSX-FAQ.texi

For everything else read the NEWS file 

stefano

Milan and Augsburg, 2004-10-10

=== Note to developers ===

If you intend to work on the source code of R.app, please adjust your editor to use tabs. Each indentation level
should be exactly one tab. The preferred setting in Xcode is (in Preferences -> TextEditing)
  [X] Editor uses tabs
  Tab width: [4] Indent width: [4]

This will give you the proper indenting behavior and fairly well readable code. You can replace the "4" in both fields by
any positive value you find pleasant, just make sure both entries are identical. Use Xcode-style indentation whenever possible.
The strict use of tabs as indentation marks makes it possible for everyone to view the code with the spacing s/he prefers.

For Emacs users the setting is (setq c-basic-offset 4 tab-width 4
indent-tabs-mode t)

Other important note:
 * always commit NIB files individually and remove and .svn directories
   before adding new NIB files: when IB copies NIBs it also copies .svn
   directories, thus screwing up the SVN.

 About Localization - Quick Overview
-------------------------------------
We have added new (experimental) support for localization of the GUI. Although this is great news for the users, this requires cooperation of the developer and some extra work. Please read "Localizing Obj-C code" amd "NIB localization" below!

There is a script "update.localization" in the project directory that automatically updates localized NIBs to match changes made in the master 'English' versions. It is the aggressive form of NIB update (see nibtool) which means that it retains only sizes of existing components, but any other changes made to the localized NIB after translation will be lost. It also generates corresponding <nib>.<lang>.strings files that can be used for translation. Any existing files (localized NIBs and NIB-relased string files) will be overwritten.

Analogously there is a script "update.strings" for automatic merging of newly added Obj-C strings. Again, read next sections for details.

** I can't stress this often enough - make sure your editor is set to UTF-8 encoding when editing localization-related files! Even the default in Xcode is MacRoman, so make sure you set it to UTF-8 in your preferences! If you don't, then Xcode will open UTF-8 files as MacRoman thus ruining the file! All localization tools described here handle UTF-8 ONLY! **

 How To - NIB localization:
----------------------------
* adding new localization
	- in Xcode, select the NIB, go to Info, click on "Add Localization"
	  use country's ISO 639 or 3166 code for the localization instead of full name
	- run update.localization -g
	  this will create translation files in Translated.strings for all NIBs and languages, including the new one
	- edit the translation file for the new NIB - right hand side must be translated. IMPORTANT: Before editing, make sure you set the encoding in the editor to UTF-8!! Not doing so will cause the translation to fail silently and you will wonder why nothing works.
	- run update.localization -t
	  this merges any changes made in the Translated.strings to NIBs
	  
	*** An important note to those with write SVN access: don't forget to DELETE the .svn FOLDER of the newly created NIB!! This is VERY IMPORTANT!! The .svn folder is copied from the original English NIB, so it will incorrectly point to the English version. If you commit this, you will overwrite the English version with your localized NIB! We definitely don't want that.

* adjusting locale-specific widgets in existing, localized NIBs
	- you can edit widgets in the localized NIBs, such as stretching them. Those changes won't be overwritten when updating the "English" master later. However, make locale-specific changes ONLY. If you want to make a change from which other locales may benefit then rather do the change in the master NIB.

* updating master NIB files
	- always base your changes on the master "English" version of the NIB
	- run update.localization
	  this synchronizes the changes made in the master with other locales. This also generates a new set of Translated.strings files
	  
	[the following is optional]
	- edit the translation file. This is necessary if new widgets have been added and thus they need to be translated. Again, make sure you use UTF-8 encoding!
	- run update.localization -t
	  again, don't forget the -t option or your new translation file will be overwritten

Some notes on NIB files:
- It is a good idea to check the translation files even if you actually don't want to translate the NIB. The file will show you any inconsistencies in the strings used, such as trailing spaces or newlines.
- When desigining a view, always keep in mind that many languages need more space for the same phrase than english. Keep sufficient space around/following a text such that the localized files don't need to be modified one by one. (I could probably remove this one if we used German as the master language ;)).
- Don't forget to re-run update.localization when you make non-GUI changes to the NIBs, such as new connections. It's easy to forget, because it has nothing to do with the GUI, but still, the localized NIBs need to be updated, too.
- Always run update.localization before a release

 Localizing Obj-C code
-----------------------

When writing code, keep in mind that all user-visible string constants should be localized. The Apple-documented way is to use NSLocalizedString macros (see Cocoa deocumentation), but to make it somewhat easier, there are NLS and NLSC macros in RGUI.h which should be used INSTEAD! They are equivalent to NSLocalizableString(xx,xx) with NLS passing an empty string as comment. The reason for the macros (beside reducing the typing effort) is that there are also some scripts that allow us to automate and simplify the process. Both macros can be used with Obj-C strings ONLY. Handling of C strings is not supported yet (use NSString whenever you can!).

Macros:
  NLS(@"text")
  NLSC(@"text", @"comment to clarify the context - not visible to user, only visible to the translator")
Examples:
  NSString *message = NLS(@"Hello, world");
  [item setValue: [NSString stringWithFormat: NLS(@"Hello, %@"), name]];
  [toolbar setLabel: NLSC(@"Add Col", @"Add column - toolbar entry, keep short!")];

The most straight-forward way to localize existing code is to replace any (user-visible) @".." string constant with NLS(@".."). Note that NSLog messages and fixed strings (e.g. keys used in preferences) should not be translated.

Once the code is ready, run (in project directory)
./update.strings
this script generates Localized.strings from the sources and merges localization from each language into a new file, replacing old localization.  It relies on two other scripts: 'filterNLS' which filters all NLS/NLSC macros and generates Localized.strings (using genstrings and iconv) and 'mergeLS' which merges changes into a localized version of the strings. In addition, empty comments (i.e. all NLS entries) are replaced by @"From: <file> (<function>)" to provide some context. Warnings of multiple key use can be safely ignored if the meaning is consistent.

Some practical notes:
- If you CHANGE the handle in the Obj-C code, the previous localization is lost. You should NEVER change the handle, unless you have really strong reason to do so. Note that changing the english text can be done through Localizable.strings, too! You don't have to change the handle to rephrase a given text.
- It is OK to change the comment part when using NLSC, because that information is not used for merging.
- One handle can have one translation only. If you need the same text in two different contexts, use different handles and change the english text in the localization file.
