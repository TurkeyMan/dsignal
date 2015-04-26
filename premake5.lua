require "monodevelop"
require "d"

solution "dsignal"
	if _ACTION == "gmake" then
		configurations { "Release", "Debug", "DebugOpt" }
	else
		configurations { "Debug", "DebugOpt", "Release" }
		platforms { "x64" }
	end


	project "dsignal"
		kind "ConsoleApp"
		language "D"

		files { "src/**.d" }
		includedirs { "src/" }

		configuration { "Debug" }
			defines { "DEBUG", "_DEBUG" }
			flags { "Symbols" }
			optimize "Debug"

		configuration { "DebugOpt" }
			defines { "DEBUG", "_DEBUG" }
			flags { "Symbols" }
			optimize "On"

		configuration { "Release" }
			defines { "NDEBUG", "_RELEASE" }
			flags { "NoBoundsCheck" }
			optimize "Full"
