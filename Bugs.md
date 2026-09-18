# Bugs Document
This document will be used as an overview to see the bugs we currently have in the game Systems Offline. With this document programmers can always come and look what needs to be fixed and what is going on. If you fix a bug please remove it from this document. 

## Bug 1: Door opening and escape bug
This bug occurred when I opened a door and try to press escape during the opening animation. This does not enter the pause menu, and after you interact with the door again it instantly reopens. (It could have to do with the animation being canceled, however it does pause during the closing animation so not to sure). Also if the mouse capture is not on and you try and click on the screen while the door is opening you get a **Cannot call method 'project_ray_origin' on a null value.**
### Possibly solved:
It seemed like the issue was due to the _unhandled_input method not being called when the door was in opening animation. So changing it to _input seems to have fixed it.
