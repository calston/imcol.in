---
title: "Monitoring streaming video with OpenCV"
date: 2016-07-02T11:04:10Z
draft: false
image: "img/generic/video-streaming.jpg"
weight: 10
categories: [ "blog" ]
showonlyimage: false
---

Streaming video presents a number of problems, and monitoring is one of the biggest - people get pretty unhappy when their TV show cuts out, or they miss the winning goal in a soccer match because of some silly issue.

What makes this challenging is that it's not all that easy to solve reliability issues with just redundancy, and there are a lot of things which can go wrong and a few areas where redundancy is all but impossible. So along with checking every component, one needs to verify the end result and check every channel to make sure the audio quality is reasonable, that there's no MPEG artifacts (which can be caused by anything from a faulty encoder to a lightning storm), and that there's actually a picture. How does that happen? People sitting around checking every channel and make sure people are seeing what they should.

The problem is a lot of quality issues are subjective, and people make mistakes (like falling asleep when The Notebook comes on) so in attempting to automate quality control and measurement, and generate alerts when things go wrong I developed this idea.

The first thing is to look at what video is - it's a stream of data, or on a lower level a multi-dimensional matrix of pixels streaming through time. Of course analysing this is a huge job for a computer, especially with a few hundred channels and endpoints, so you need some dimensional reduction.

## The histogram

If you've ever used photo editing software you've probably seen something called the histogram. What it represents is the frequency of colour intensities in the image, which is useful for detecting when videos plummet into darkness.

{{< figure src="/post/images/histo-300x150.png" title="Video histogram" >}}

Looking at a histogram, the things we do want and don't want are immediately obvious but how does this look with an extra dimension, namely time?

Taking a random TV show and smoothing out a histogram for each frame and plotting that as a surface to see what's going on turns out like this.

{{< figure src="/post/images/figure_1-300x177.png" title="3D histogram" >}}

Pretty, but still too many dimensions to monitor real time (fortunately I have a monstrous workstation to generate these graphs). [Source here](https://gist.github.com/calston/b82e64de639367595084)

Obviously what we don't want is the histogram leaning heavily to the right or left, but more importantly we expect it to have some high degree of variance to indicate things are changing andmoving. So the first thing we do is reduce the dimension by taking the sum of pixels and calculating the percentage of each luminosity value. Then we sum the multiple of those and arrive at just a value of how light or dark each frame is. This gives us a value from 0 to 255 which indicates where the histogram peaks, which ideally is not near the extremes if there is some sort of visible picture.

{{< figure src="/post/images/figure_2-1024x441.png" title="Histograms" width="600" >}}

You can clearly see the value drop off when the credits roll, but there's still variance which gives us a good idea that something is going on. Snow, test patterns or black screens will have a very low variance.

## Motion detection

Tracking the variance in the histogram gives us an idea that there's something resembling a video, but it's not enough on its own to draw a conclusion. Another good indicator is some simple motion detection. 

We can get a matrix of changed pixels by calculating the difference between frames with a simple XOR filter.

```python
def frameDiff(t0, t1, t2):
    d1 = cv2.absdiff(t2, t1)
    d2 = cv2.absdiff(t1, t0)
    return cv2.bitwise_and(d1, d2)
```

[More here](http://www.steinm.com/blog/motion-detection-webcam-python-opencv-differential-images/)

## Sending it all to Riemann

Using Python and OpenCV this is what we end up with the following functions which take the 95th percentile of motion changes as a percentage of the visible area, and returning the mean and variance in the histogram value.

```python
import cv2
import numpy

def frameDiff(t0, t1, t2):
    d1 = cv2.absdiff(t2, t1)
    d2 = cv2.absdiff(t1, t0)
    
    return cv2.bitwise_and(d1, d2)
    
def processStream(chan, fname):
    cap = cv2.VideoCapture(fname)
    bright = []
    frameBuffer = []
    tdiff = []
    while cap.isOpened():
        ret, frame = cap.read()
        if ret:
            gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
            frameBuffer.append(gray)
            r = cv2.calcHist([gray], [0], None, [256],[0,256])
            cv2.normalize(r, r, 0, 255, cv2.NORM_MINMAX)
            # Calculate value
            v = sum(r)
            ev = sum([i * (c/v) for i,c in enumerate(r)])[0]
            bright.append(ev)
            # Perform motion detection
            if len(frameBuffer)==3:
                diff = frameDiff(*frameBuffer)
                h = len(diff)
                w = len(diff[0])
                avm = (sum(sum(diff)) / float(h*w))*100
                tdiff.append(avm)
                frameBuffer = []
            else:
                break
                
            cap.release()
    if bright:
        avsq = float(numpy.mean(bright))
        sqvar = float(numpy.var(bright))
        vmotion = float(numpy.percentile(tdiff, 95))
    else:
        avsq, sqvar, vmotion = 0, 0, 0
        
    return avsq, sqvar, vmotion
```

{{< figure src="/post/images/motion1.png" title="Motion graph" >}}
