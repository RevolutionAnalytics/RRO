/*
 *  InfoPlist.h
 *  R
 *
 *  Created by Simon Urbanek on 10/23/08.
 *  Copyright 2008-2014 R Foundation for Statistical Computing. All rights reserved.
 *
 */

/* GUI version as shown in infos e.g. 1.27-devel */
#define GUI_VER 1.66
/* R postfix used to denote release versions of GUI - set to R release version (e.g. 2.8.0) or to anything that will be shown in between R and GUI (e.g. - or for Mac) */
#define R_RELEASE 3.2.1

#if RELEASE_CFG
/* for release config just auto-detect the SDK used */
/* we cannot use Availability.h because of the odd processing Xcode uses here! */
#define MIN_VER __ENVIRONMENT_MAC_OS_X_VERSION_MIN_REQUIRED__
#if MIN_VER >= 1090
#define CFG_NAME Mavericks build
#elif MIN_VER >= 1080
#define CFG_NAME Mountain Lion build
#elif MIN_VER >= 1070
#define CFG_NAME Lion build
#elif MIN_VER >= 1060
#define CFG_NAME Snow Leopard build
#else /* don't bother with the real name if older - just if it's 64-bit or not */
#if __LP64__
#define CFG_NAME 64-bit build
#else
#define CFG_NAME 32-bit build
#endif
#endif /* older SDK */
#endif /* RELEASE_CFG */

#if LEOPARD_CFG
#define CFG_NAME Leopard build 32-bit
#endif
#if SNOWLEOPARD_CFG
#define CFG_NAME Snow Leopard build
#endif
#if LEOPARD64_CFG
#define CFG_NAME Leopard build 64-bit
#endif
#if DEPLOY_CFG || DEPLOYMENT_CFG
#define CFG_NAME Tiger build 32-bit
#endif
#if DEPLOY64_CFG
#define CFG_NAME Tiger build 64-bit
#endif
#if DEBUG_CFG
#define CFG_NAME Debug build
#endif
#if DEVELOPMENT_CFG
#define CFG_NAME Development build
#endif
#ifndef CFG_NAME
#define CFG_NAME unknown
#endif
