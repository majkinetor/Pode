if ((Get-Module -Name Pode | Measure-Object).Count -ne 0)
{
    Remove-Module -Name Pode
}

$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -ErrorAction Stop

# or just:
# Import-Module Pode

# create a server, and start listening on port 8090
Server -Force {

    # tell this server run as a desktop gui
    gui 'Pode Desktop Application' @{
        'Icon' = '../images/icon.png'
    }

    # listen on localhost:8090
    listen 127.0.0.1:8090 http

    # allow the local ip and some other ips
    access allow ip @('127.0.0.1', '[::1]')

    # set view engine to pode renderer
    engine pode

    # GET request for web page on "localhost:8090/"
    route 'get' '/' {
        param($session)
        view 'gui' -Data @{ 'numbers' = @(1, 2, 3); }
    }

}