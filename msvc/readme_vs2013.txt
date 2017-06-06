Why use pg_repack.2013.sln
pg_repack.2013.sln allows you to build easily pg_repack with a version of EntrepriseDB's PostgreSQL comming from EntrepriseDB installer.

How to build with Microsoft Visual C++ 2013 with pg_repack.2013.sln

You might need:
  1. Register PostgreSQL directory to your environment :
        - PostgreSQL32 for 32 bits version
		- PostgreSQL64 for 64 bits version
  2. Resolve redefinitions of ERROR macro.

----
1. Register PostgreSQL directory to your environment.

Add to your environment variables :
  - PostgreSQL32 for 32 bits version with the path of your postgreSQL 32 bits installation directory (ex : C:\Program Files\PostgreSQL\9.6)
  - PostgreSQL64 for 64 bits version with the path of your postgreSQL 64 bits installation directory


----
2. Resolve redefinitions of ERROR macro.

It might be a bad manner, but I'll recommend to modify your wingdi.h.

--- wingdi.h       2008-01-18 22:17:42.000000000 +0900
+++ wingdi.fixed.h 2010-03-03 09:51:43.015625000 +0900
@@ -101,11 +101,10 @@
 #endif // (_WIN32_WINNT >= _WIN32_WINNT_WINXP)

 /* Region Flags */
-#define ERROR               0
+#define RGN_ERROR           0
 #define NULLREGION          1
 #define SIMPLEREGION        2
 #define COMPLEXREGION       3
-#define RGN_ERROR ERROR

 /* CombineRgn() Styles */
 #define RGN_AND             1
