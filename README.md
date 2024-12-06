This module was fully created by me, @Viv3k_87 on Discord

The module will prodcue a compressed PNG image file given the RGB values.
The values are compressed using the DEFLATE compression algorithim as per the PNG standard. The Deflate function produces a fully valid Zlib stream.

NOTE: The module only works in Lua 5.3 and greater because it uses the native binary operators, which are not supported under this version

The EncodePNG function only takes the pixel values in the following format:

local img = {

 { {255, 0, 0}, {0, 255, 0} }, --row 1 of pixels
 
 { {0, 0, 0}, {0, 0, 255} } --row 2
 
 }
 
This would represnt a 2 by 2 image with red in the top left, green in the top right, black in the bottom left and blue in the bottom right.
You may also add a 4th value in all pixels for an alpha value.

NOTE: all color values must be integers from 0-255 or the module will error

Heres the explanation of the arguments you must pass: 
- Width: width in pixels of image
- Height: height in pixels of image
- Pixels: The actual RGB values represnting the image colors
- Colortype: only colortypes 2 and 6 are currently valid, pass the number 2 for RGB images or 6 for RGBA images
- FilterOn: Boolean value, pass true if you would like the compressor to attempt filtering the pixels for better compression (will take longer to compress) or false if not

For the image above you would call the function like this: 

local EncodePNG = require(PngEncoder.lua file path)

EncodePNG("FileName", 2, 2, img, 2, true)

You may want to edit the PNGEncoder Module to decrease MaxSearchDepth in the ChooseMatch function or decrease the LZ77 window size defined at the top of the module,
or even choose to use uncompressed blocks to try and speed up the generation time, but it will likely result in expansion.
