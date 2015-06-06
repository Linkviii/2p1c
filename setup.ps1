#Download and move files for 2p1c

$shell_app=new-object -com shell.application

#Download prereq
$url = "http://sourceforge.net/projects/bizhawk/files/Prerequisites/bizhawk_prereqs_v1.1.zip/download"
$filename = "bizprereq.zip"
Invoke-WebRequest -Uri $url -OutFile $filename -UserAgent [Microsoft.PowerShell.Commands.PSUserAgent]::FireFox
#unzip prereq
$zip_file = $shell_app.namespace((Get-Location).Path + "\$filename")
$destination = $shell_app.namespace((Get-Location).Path)
$destination.Copyhere($zip_file.items())

#Download Bizhawk
$url = "http://sourceforge.net/projects/bizhawk/files/BizHawk/BizHawk-1.9.4.zip/download"
$filename = "bizHawk-1.9.4.zip"
Invoke-WebRequest -Uri $url -OutFile $filename -UserAgent [Microsoft.PowerShell.Commands.PSUserAgent]::FireFox
#Unzip
$zip_file = $shell_app.namespace((Get-Location).Path + "\$filename")
mkdir BizHawk-1.9.4
$destination = $shell_app.namespace((Get-Location).Path + "\BizHawk-1.9.4")
$destination.Copyhere($zip_file.items())

#Download luasocket
$url = "http://files.luaforge.net/releases/luasocket/luasocket/luasocket-2.0.2/luasocket-2.0.2-lua-5.1.2-Win32-vc8.zip"
$filename = "luasocket-2.0.2-lua-5.1.2-Win32-vc8.zip"
Invoke-WebRequest -Uri $url -OutFile $filename -UserAgent [Microsoft.PowerShell.Commands.PSUserAgent]::FireFox
#unzip
$zip_file = $shell_app.namespace((Get-Location).Path + "\$filename")
mkdir luasocket
$destination = $shell_app.namespace((Get-Location).Path + "\luasocket")
$destination.Copyhere($zip_file.items())

#download 2p1c
$url = "https://github.com/LumenTheFairy/2p1c/archive/v1.0.0.zip"
$filename = "2p1c-1.0.0.zip"
Invoke-WebRequest -Uri $url -OutFile $filename -UserAgent [Microsoft.PowerShell.Commands.PSUserAgent]::FireFox
#unzip
$zip_file = $shell_app.namespace((Get-Location).Path + "\$filename")
$destination = $shell_app.namespace((Get-Location).Path)
$destination.Copyhere($zip_file.items())

#Copy files into Bizhawk
cp .\luasocket\mime .\BizHawk-1.9.4\
cp .\luasocket\socket .\BizHawk-1.9.4\
cp .\luasocket\lua\* .\BizHawk-1.9.4\Lua\
cp .\luasocket\lua5.1.dll .\BizHawk-1.9.4\dll\
cp .\2p1c-1.0.0\2p1c\* .\BizHawk-1.9.4\
cp .\2p1c-1.0.0\2p1c.lua .\BizHawk-1.9.4\