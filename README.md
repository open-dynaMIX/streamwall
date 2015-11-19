#streamwall
Distributed under the GNU GPL  
http://www.gnu.org/licenses/gpl-3.0.txt  
Or see the file ./COPYING


##Introduction
Set images from livestreams as wallpaper at a given interval.  
By default it uses the HDEV-stream from the International Space Station  
(ISS).

With the `-s` option, you can use any another livestream that can be handled  
by `livestreamer`.  
See `man livestreamer` for more information.

You can find the actual and the previous wallpaper in `~/.streamwall`

`streamwall` is not affiliated or endorsed by NASA.


##Dependencies
streamwall depends on:
 - livestreamer
 - ffmpeg
 - imagemagick

Optional (default for setting wallpaper):
 - feh


##Usage
```
Usage: streamwall [OPTIONS]

Optional arguments:
  -h              Show this help message and exit
  -s <url>        Stream url (defaults to
                    'https://www.ustream.tv/channel/iss-hdev-payload')
  -q <quality>    Quality (defaults to 'best'. See 'man livestreamer'
                    for more information)
  -o              One-shot
  -b              Ignore blank images
  -n              Ignore error-images from ISS
  -t              Put a timestamp on the wallpaper
  -f <command>    Command to set the wallpaper (defaults to
                    'feh --bg-scale {%FILE}')
  -w              Seconds to wait before getting the next image
                    (defaults to 120)
  -d              Print debug-messages
```


##Using custom streams
With the `-s` option, you can use a custom livestream that can be handled by  
`livestreamer`.

If you want to filter certain images from showing up as wallpaper, you can  
fetch those images and put them in a folder `~/.streamwall/filters/`.

`streamwall` will search that folder for those images. The default threshold  
for comparing images is 20. If you want to change that, you can add it as  
last part of the filename, just before the file-extension (e.g.  
`~/.streamwall/filters/white_30.png`).


##High Definition Earth-Viewing System (HDEV)
From http://eol.jsc.nasa.gov/HDEV/  
The High Definition Earth Viewing (HDEV) experiment aboard the ISS was  
activated April 30, 2014. It is mounted on the External Payload Facility of  
the European Space Agency’s Columbus module. This experiment includes several  
commercial HD video cameras aimed at the Earth which are enclosed in a  
pressurized and temperature controlled housing. While the experiment is  
operational, views will typically sequence though the different cameras.  
Between camera switches, a gray and then black color slate will briefly  
appear. To learn more about the HDEV experiment, visit here[1].

[1] https://www.nasa.gov/mission_pages/station/research/experiments/917.html

