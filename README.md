# 1D_Life_In_Z80_Turbo_Version
A faster screen draw routine that does not rely on the MOS to scroll - the MOS screen update process is relatively slow as it apparently has to copy the contents of the screen back to RAM, update it and send it back again each time it has to scroll. The is slow and leads to artefacts briefly flashing up on the screen. In the case of 'https://github.com/LardoBoffin/1D_Life_In_Z80_For_The_Tatung_Einsten-in' this means life briefly appears where it should not, which I guess is very much in keeping with life...

The screen setup routines and copy of the screen buffer to VDP were supplied by AI as I am still trying to figure out how the VDP works having come from computers with main RAM mapped screens such as the BBC Micro. 

The basic process is to write the output to a 960 byte buffer (1 byte per character) and then when a new line of text is ready to be displayed move the data up a row, put the new data at the bottom of the screen and then send the whole lot to the VDP after waiting for a vertical blank. The creatures scroll up the screen at a ridiculous rate with no untoward artefacts. 

Currently the creatures start appearing at the bottom of the screen and instantly scroll but they need to start at the top, fill the screen and then scroll - To Do!
