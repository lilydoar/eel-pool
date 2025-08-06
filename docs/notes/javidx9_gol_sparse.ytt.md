# https://www.youtube.com/watch/OqfHIujOvnE

00:00:00.240 Hello. Let's create life again uh but this time much much bigger. I
am of

00:00:06.000 course talking about Conway's game of life, a topic we've covered
before on the channel and we'll have a look at that later. I've always liked the
game

00:00:13.120 of life. Here is an ar pentomino shape. And if I start the
simulation, we can

00:00:18.800 see that it evolves and fluctuates and moves around. It's really
quite beautiful. We've got things that move,

00:00:24.880 things that grow, things that die. And this is an algorithm that's
fascinated

00:00:29.920 computer scientists for a long time. Look at that. It sent out
these little streamers and they're going out into the void until they encounter
something

00:00:36.880 else. You can see we've got some simulation going on here as well.
At any point I

00:00:42.320 can sort of disrupt the stim simulation by stimulating it.

00:00:48.239 And I can right click with my mouse to place a whole load of random
cells too. It's a nice way to draw things. Now, the

00:00:54.800 previous video I did on cellular automata and specifically the game
of life was limited to a reasonably small

00:01:01.280 size. So, I thought, wouldn't it be more interesting if we had a
really huge cellular automata universe going on? So,

00:01:08.240 this is a real game of life simulation all happening in real time
and I can interact with any part of it. Now, you

00:01:14.560 as I zoom out, you'll be able to see less and less of it in the
YouTube video, I'm sure. But, uh, when I say

00:01:19.680 big, I don't just mean big. I mean really big. So, let's keep
zooming out and having a look at how many cells

00:01:25.520 we've got. Now, there's probably quite a few million cells being
simulated. Uh,

00:01:31.280 and I don't mean well, really big. I mean really, really, really
big. Let's keep zooming out now. Oh, here we go.

00:01:37.840 So, we've got some more simulation going on over here. Now, this
was literally millions, if not billions of cells away.

00:01:44.640 These ones look quite symmetrical, and that's quite nice because if
I simulate um a bunch like that, this is all

00:01:50.799 random. you just get this random effect. But if I pause the
simulation and fill in a whole square like this. Look at

00:01:56.320 this. This is beautiful. We get this beautiful symmetrical growth
pattern going on. I really like this.

00:02:06.399 And eventually this pattern sends out some streamers into the
distance.

00:02:12.800 Oh, there they go. Off we go into the diagonals. And they're just
going to swim off into

00:02:18.560 the void as these ones have done already. Let's have a quick look
at these and zoom right in on one of them. There they go. They're off to
discover

00:02:25.040 something else in their universe. The entire size of the universe
in this simulation is theoretically infinite.

00:02:32.640 And this is a considerably different approach to implementing
cellular automata than I've shown in the previous

00:02:38.319 video many many hundreds of years ago. Let's take a quick look at
that. Hello.

00:02:45.680 This week I created artificial life at the command prompt of
course. Look at this handsome chap. Ah, the old

00:02:52.640 studio. I miss you. If you're completely unfamiliar with the game
of life and cellular automata, it's worth watching

00:02:59.040 this quick 15-minute video. The rules still apply, and I'm not
changing anything here, and I have no intention

00:03:04.640 of repeating these rules for this video. It used a precursor to the
OLC Pixel

00:03:10.400 game engine called the OLC console game engine. It was pretty much
the same thing except it did everything in a

00:03:16.000 command prompt. I think the first thing we're going to need to do
is very quickly update the code. Who is that

00:03:22.319 guy? He didn't even have any gray hair. How can he possibly know
anything about programming? If you hop on over to the

00:03:28.000 one lone coder GitHub, uh you can go to the console game engine
section and look at the smaller projects for the entire

00:03:34.560 implementation of the game of life in that video. It wasn't a very
long implementation, just a couple of hundred

00:03:40.879 lines. I'm going to copy that code and paste it into a new Visual
Studio project. I've pasted in the original

00:03:47.440 code. I've now told it to include the pixel game engine instead of
the console game engine. Naturally, I inherit from

00:03:54.000 the pixel game engine instead. I've removed this little lambda
function here because it used a string type to

00:04:00.000 represent some graphics. It's actually not relevant to anything
we're doing today. I changed the drawing code from

00:04:05.280 drawing white characters to white pixels. And I launched the
application using the construct function instead of

00:04:11.680 the construct console function. So, let's run it and take a look.
Excellent. We can see Game of Life happily fizzing

00:04:18.160 away here. In fact, it's simulating very quickly indeed. On my
machine right now, 4 and a halfish thousand frames pers of

00:04:24.639 update. It had a boundary condition which stopped it from dying.
That was more of a bug actually, but it kept it

00:04:30.639 alive and made it visually interesting. For today's video, what's
quite nice is it's almost exactly the same code as it

00:04:36.240 was 8 years ago, and it still just works fine. The simulation runs
very fast

00:04:41.520 because the space being simulated was very small. At the time, it
was set to be the same size as the command prompt,

00:04:47.840 which was 160 by 80 characters. Let's make it much bigger now and
see what effect that has on performance. Because

00:04:54.800 everywhere in the code is sensitive to the size of the command
prompt, all we need to do is change our launch

00:05:00.960 parameters to change the size of the simulation. I'm going to
change this to something a little bit more modern,

00:05:06.960 1280x 960. And I'm not going to have eight pixels per screen pixel.
I'm just

00:05:12.400 going to have onetoone relationship. Let's take a look. Firstly,
what was interesting there before the YouTube

00:05:17.759 compression kicked in is how rubbish Rand was. But secondly, we're
almost at 1 megapixel now. And we can see we've

00:05:24.080 dropped down to 30 frames pers. The simulation is still ticking
away very nicely, although it's hard to see.

00:05:31.360 Recall that this code was written before we had any of the
modern-day amenities the channel has become used to, such as

00:05:37.039 panning and zooming. Let's make the simulation even bigger now.
Let's have four megapixels of space being

00:05:43.520 simulated. This won't fit on one screen. Again, we can see just how
rubbish Rand is. Look at all of that repetition

00:05:49.919 there. Anyway, we've talked about that before in the procedurally
generating universe video. I'm just going to shrink

00:05:55.120 this screen down so we can kind of see some of it. See, it's well
too big for my monitor. There we go. Now, of course,

00:06:02.400 at this resolution, a lot of the data won't be being drawn, but
look at that. Look at those patterns. I do find that

00:06:07.600 fascinating, completely distracting part of this video. However,
the simulation is now running. It's running at 4

00:06:13.280 megapixels and we're about five frames pers. Let's just put that
into perspective. That's literally 4 million

00:06:20.639 cells being simulated uh five times a second. That's quite a lot of
simulation. But it also reveals a

00:06:27.120 limitation. As we get bigger, all of those cells require additional
computation. So, the simulation gets

00:06:33.360 slower. That might be fine if you can leave it overnight to get the
results that you want, but it's a little

00:06:38.800 infuriating for casual coders like me. So, it goes without saying
we can't simply scale the simulation space to be

00:06:45.520 as big as we want. And so, I'm going to rely on a different way to
encode the cells. That should allow us to have very

00:06:51.919 large simulations indeed. Traditionally, when we simulate a 2D
space, we specify

00:06:57.120 an array of a certain size. I'm going to assume it's 0 0 up here.
And in the

00:07:02.160 original simulation, it was 160x 80. This gave us 12,800

00:07:09.440 individual pixels. 50 years ago, that would have been one tough
simulation to do, but as computer hardware has

00:07:16.160 evolved, it's no longer challenging. And we can actually use much
larger sizes, as we've just demonstrated, and still

00:07:21.840 maintain reasonable frame rates. And it goes without saying that if
we scale this image, then the number of cells

00:07:28.479 also scales too, making the computational challenge much more
difficult. Not only do we need memory to

00:07:34.560 represent all of the cells in this space, we then need the compute
resources to chew through them all. But

00:07:40.000 understanding the content of this image is important. A cell is
well a dot. It's

00:07:46.319 a pixel in that image and it has a state of true or false. If we've
got just one

00:07:52.800 cell in our whole image, it has to be more effective to store the X
and Y

00:07:59.199 coordinates of that cell. And if we had several, then we maintain a
container of

00:08:04.800 cells with X and Y locations. Reducing a space of information to
just where the

00:08:11.680 information is is a form of sparse encoding. And we see this quite
often in

00:08:17.199 computer science, not just with game of life simulations, but also
with very large matrix representations. We're

00:08:23.840 relying on the fact that most of the space in our simulation space
is empty.

00:08:32.320 Naturally, there's a tipping point. If we had lots and lots of
active cells in

00:08:37.360 our image, it might become more efficient to store them all. So
sparse encoding isn't necessarily a golden

00:08:44.159 bullet, but if you take something like Game of Life in a huge
universe, then

00:08:49.360 most of that universe is indeed empty. And so it makes more sense
just to represent the cells that are active at

00:08:55.839 any given time. Game of Life is all about a cell knowing what's
going on with its neighbors. So given an active

00:09:03.200 cell that I've got here, we need to check all of the neighbors to
see what their state is. we count how many of

00:09:10.160 them are active and that count then determines whether the cell
lives or dies from overcrowding, loneliness or

00:09:17.680 reproduction. Now if we represented our cell as some sort of
structure with an x

00:09:23.680 and y coordinate, we could maintain a vector of cells. In fact, we
would only

00:09:30.320 need to store the active cells. At first glance, this is great
because the vector

00:09:35.600 will grow and shrink as the number of active cells increases or
decreases. But fundamentally, there is a problem with

00:09:42.160 this approach. If we know the X and Y coordinate of the cell we're
currently updating, and we need to interrogate its

00:09:50.080 neighbors by offsetting that X and Y accordingly, how do we know if
such a

00:09:56.399 cell exists in our vector to understand whether it's active or not?
Well,

00:10:01.600 somewhat inconveniently, the only way to do this would be to search
through the whole vector every single time and see

00:10:08.560 if a cell with the address matching the description we need exists
within it. The standard vector has no built-in

00:10:14.800 locality or any kind of spatial awareness. It also potentially
allows

00:10:19.920 duplication of cells, which means some cells could be processed
twice. So

00:10:25.120 perhaps we should think a little differently about how we're
representing an active cell. Given the state of a

00:10:31.519 cell is binary, it's true or false, then the existence of a cell
within the container reflects the state of the cell

00:10:38.800 in the simulation. The only other properties of interest are the
cell's location. Therefore, if we had a

00:10:46.480 container of locations, we could perhaps test to see if a specific
location

00:10:52.240 exists within the container to tell us whether that cell is active
or not. And fortunately for us, such a container

00:10:59.360 exists. It's called a standard. I'm not going to have enough room
here. Unordered set. And I'm going to

00:11:06.480 represent the location as an integer XY pair.

00:11:12.880 Using a standard unordered set has some advantages. Firstly, a set
is

00:11:18.079 approximately the size of its contents. It will grow and shrink in
memory.

00:11:23.279 Secondly, it doesn't allow duplicates. And thirdly, we don't need
to do an

00:11:28.800 iterative search to determine if a specific location is stored
within the

00:11:34.320 set. Unordered sets use a hash of the thing they are storing to
determine

00:11:40.320 where it should be stored within its internal structures. It's
unordered. We don't have any control over that. But it

00:11:46.480 does mean we can determine relatively quickly the presence of a
location within our set of active cells which in

00:11:53.760 turn means that specific cell is indeed active. This means we can
check a cell's

00:11:59.040 neighbor activity by using the contains function passing in the
address of a

00:12:04.160 cell and some XY offset as required. If

00:12:09.360 this returns true, then the neighbor exists and is active. Now I
know that there are some container

00:12:16.320 and C++ aficionados out there that will perhaps pull their nose up
a little bit at the standard unordered set approach.

00:12:23.040 There are faster implementations than that usually provided by the
compiler vendors. However, I'm sticking with it

00:12:28.639 for this example because if somebody wanted to try along, it's
ubiquitous and it's ready and it's included with your compiler. Let's look at
implementing

00:12:35.440 this now by modifying the original code. We can see here the two
fundamental states of the cell in the previous

00:12:41.839 simulation. They were simply arrays. We're now going to represent
the state of a cell by its existence within a set

00:12:49.040 of active cells. Firstly, I'll need to include unordered set.

00:12:56.639 Secondly, my unordered set doesn't know how to hash an OLC vi 2D
structure. This

00:13:03.360 is an integer 2D location. It's a 32-bit integer as well. So, even
though I've been saying everything is infinite, the

00:13:09.920 reality is our simulation is about 4 billionx 4 billion cells. To
tell an

00:13:15.200 unordered set how to hash something, you need to provide a little
hashing function. I'm calling mine hash OLC vi

00:13:21.440 2D and I'm going to declare that up here. To provide a hash, we
overload the cast operator for our specific type.

00:13:28.639 Now, a vid consists of an x and a ycoordinate. Hashing that is very
simple

00:13:33.839 indeed because I'm going to take my two 32-bit elements and cast
them to a 64-bit element, which means all I need

00:13:40.399 to do is stack them side by side in memory. This is convenient
because it guarantees I'll never have any hash

00:13:46.959 collisions for given values of location. It's also computationally
very simple.

00:13:52.560 So hopefully nice and speedy. Many times throughout the computation
of the game of life, I'm going to need to know if a

00:13:58.240 particular location is active or not. So I'm going to create a
little function called get cell state which takes in a

00:14:05.279 2D location and checks to see if the set contains that location.
Instead of using

00:14:10.880 booleans true and false, I'm going to use numeric here. That's
staying in line with how we did the actual game of life

00:14:17.519 implementation down below. Since we're no longer using state
arrays, all of this initialization code can go.

00:14:25.440 And previously, we would iterate through every single cell within
that state space and update it. We're not going to

00:14:31.440 be doing that anymore either. We're not even going to be drawing
them based on their existence within the array.

00:14:37.440 So basically all of this code can go too. H well that doesn't leave
us with

00:14:44.560 very much now does it? But I think the removal of all of the
existing code just underlines how moving from a state-based

00:14:51.600 implementation to a sparsebased implementation is fundamentally
different and requires a fundamentally

00:14:59.120 different way of thinking. Firstly I'm only going to simulate
anything if I'm holding down the space bar. Recall in

00:15:06.800 the previous video that we had two states for each cell, its
current state and its output. In theory, that's

00:15:13.120 considered its next state. This is because we have to update all of
the cells together in one epoch. We need to

00:15:20.639 do the same here. So, even though we're not storing all of the
cells in an array, we are storing them in our set.

00:15:26.320 So, I'm going to have an additional set called active next, which
represents all of the cells that are going to be active

00:15:32.880 in the next epoch. Therefore, at the start of the simulation of
this epoch, I'm going to set all of my active cells

00:15:40.240 to those that were considered active in the next epoch. Then I'm
going to do a little bit of set optimization. Since

00:15:45.839 this run through of the simulation will set active next cells, I'm
going to clear that set, but then I'm going to

00:15:52.480 reserve memory for it of approximately the same size as our set of
active

00:15:58.000 cells. This might help because typically there isn't a large change
between the number of cells per epoch and it will

00:16:05.199 help reduce the number of dynamic allocations that the set
implements behind the scenes. If a cell exists in

00:16:11.759 our set of active cells or comes into existence, then it will
naturally affect

00:16:17.680 the cells around it. It has the potential to change the state of
those cells. Other way to think about this is

00:16:25.360 how does this cell know that this cell exists? This cell is not
currently in

00:16:31.680 any set at all. It doesn't exist and therefore can't possibly
partake in any

00:16:37.600 future computations. We need a set of cells that have the potential
to change

00:16:42.720 in the next epoch. And conveniently, if we know which cells have
the potential to change, then they are the only cells

00:16:50.160 that need to be computed. I'm actually going to introduce two new
sets. Set potential and set potential

00:16:57.759 next where set potential is a set of all of the locations that have
the potential

00:17:03.279 for change in this epoch. Just as we did with set active,

00:17:08.480 I need to update set potential to set potential next at the start
of this simulation epoch. Now, instead of

00:17:15.520 clearing set potential next, I'm going to set it to the active set
of cells

00:17:21.439 because we know that all active cells in this epoch can potentially
stimulate

00:17:27.679 change in the next. So now I have a set of all the locations that I
need to

00:17:32.880 evaluate for this round of simulation. Let's create a little auto
for loop to

00:17:38.000 iterate through all of the locations in that set. And here is where
we see our first major reduction in compute

00:17:44.559 resource requirement because now we're only going to look at the
locations in the simulation space where there are

00:17:50.720 active cells or there is the potential for change this epoch. Just
as we did in

00:17:55.760 the first version, I'm now going to count the number of active
cells by calling our get cell state function with

00:18:03.520 the location. This will be immediately hashed and the container
will yield whether it exists within it or not. Now,

00:18:10.799 let's implement the rules of Conway's game of life. If the current
cell is active, we're going to do one thing, and

00:18:17.360 if it's dead, we're going to do something else. Why would we have a
dead cell in this set? Well, don't forget

00:18:23.600 this set potential is not just the active cells, it's also all of
the cells

00:18:28.720 that have the potential to change. So, let's start with the dead
state first. The rules suggest that if a dead cell

00:18:36.640 has three neighbors then the cell becomes active or else the cell
remains

00:18:43.200 dead. If the cell remains dead then we don't need to do anything at
all. However, if those three neighbors got it

00:18:49.760 on and produced a new cell then we need to insert it into our set
of active in

00:18:54.799 the next epoch cells. A new cell has been born. As a new cell comes
into existence, it has the potential to

00:19:02.080 change its neighboring cells. So, I'm going to have a little tiny
nested for loop here that just goes around the

00:19:08.000 immediate neighbors of the cell and inserts those into the
potential next set. If these locations already existed

00:19:15.520 within the set, it doesn't matter because the set doesn't allow
duplicates. Now, if the cell is already

00:19:21.360 alive, it can die from loneliness or overcrowding. But if it's got
two or

00:19:27.200 three neighbors, it's quite happy and lives on. So in the event of
the cell being unhappy, the cell needs to die.

00:19:35.679 That means it doesn't make it into the set of active next epoch
cells.

00:19:42.080 Cell death is a change, however. So we need to tell the neighbors
of that cell that potentially they're going to

00:19:48.720 change. This is the same as this little loop below. If the cell was
happy and

00:19:54.000 wants to live on, then we just simply insert its location into the
set of next cells. Fundamentally, we now have two

00:20:01.360 important sets that tell us what to do next. We have the set of all
of the active cells in the next epoch, and we

00:20:08.400 have the set of all of the locations in the simulation space we
need to check to see if they're going to become active or

00:20:15.360 die or affect their neighbors in any way, shape, or form. You can
see that in the next round of simulation, you can

00:20:21.440 see that that potential next gets set to the current potential loop
we're about to scroll through and therefore all of

00:20:27.360 those cells get updated. Fundamentally, we are only performing
computation where

00:20:32.640 we need to do computation. Once we have finished the simulation,
the next thing to do is draw the set of active cells on

00:20:40.400 the screen. Well, the set of active cells is just a set of
locations. So we'll draw a white pixel in all of those

00:20:47.120 locations in the set. We'll have to clear the screen first.

00:20:52.960 Fundamentally the rules of game of life have not changed. But the
implementation of state and epoch management is

00:20:59.520 significantly different. We have still got something missing
however and that is we can't inject any stimulus into the

00:21:06.320 simulation. I'm going to add some mouse sensitivity that if we are
holding down in this case the left mouse button

00:21:13.919 we get the location of the cursor on the screen and we insert into
both sets of activity that location. The reason I'm

00:21:21.200 doing it in both is because I want to draw where we've just
inserted new

00:21:27.039 cells. But I want the simulation to also take that into account.
Because we've inserted some new cells, we also need to

00:21:34.400 insert the potential for change in the locations of that cell's
neighbor. One

00:21:39.679 final change to make is launching the simulation. Let's just make
it a bit more manageable. Right now, I'm going to

00:21:46.240 go with the one loan coder classic 256x 240 with 4x4 pixels. Let's
take a look.

00:21:54.240 Well, a blank screen. And as you can see, I can click and draw
pixels at the

00:22:00.240 mouse location. And if I hold down space, well, they all
disappeared. That's simply because there was nothing

00:22:06.559 there that satisfied going to the next round. Let's draw a bit more
of an interesting shape. Oh, blam. Really

00:22:12.159 quick. Okay. Well, it looks like Game of Life is actually working
quite well. We

00:22:17.440 can play with this. Let's draw the R pentomino. I'm sure I'm
pronouncing that incorrectly. Oh, I've drawn it wrong

00:22:22.640 already. Let's try again. Up here. Uh, that one. Then that one,
then that one, then that one. Ready? Boom. Look at

00:22:29.440 that. All of that activity from such a small stimulus. We can see
we've got traditional game of life things in here.

00:22:35.600 There's only so many that represent stable states. These ones are
oscillators that flick between one state

00:22:41.120 and the other. You can start to upset some of these by drawing in
real time. There we are. Game of life happening

00:22:47.120 very, very quickly. Indeed. The problem is we're limited to what we

00:22:53.760 can see. Even though the game of life we can see quite happily,
it's throwing off all of these streamers in random

00:22:59.200 directions. They're still in existence, of course, they're
somewhere else in our simulation space. So, I'm going to add a

00:23:05.760 pixel game engine trick to allow us to explore that space with
panning and zooming. And this is really just two or

00:23:12.000 three lines of code. Now, in Pixel Game Engine 2, you can pull in
an extension called a transformed view. I will lay

00:23:19.679 down the gauntlet now and say that in Pixel Game Engine 3, this is
all fundamentally built in, but we'll leave

00:23:25.760 it at that. We'll need an instance of a transformed view. I call
that TV. And I'm going to initialize the TV in on

00:23:33.440 user create to be the size of the screen. In our onuser update
function, every single frame, I'm going to call

00:23:40.400 transform view handle pan and zoom. When we call the get mouse
position, that's

00:23:45.679 in screen space. We now want to convert that to world space
according to our

00:23:50.799 transformed view. So I'm going to call the screen to world function
to convert that. Now this is where things get a

00:23:57.120 little bit tricky and does highlight a limitation of this approach
when visualizing game of life. The draw

00:24:03.360 function draws a single pixel in what is effectively a sprite and
that sprite is drawn to the screen. We now effectively

00:24:10.159 have an infinitely large sprite which of course we can't have. So
instead of drawing a pixel, I'm going to draw a

00:24:16.960 small rectangle instead. This is also required because the zooming
will change from a single pixel to quite a number of

00:24:24.000 pixels depending on the zoom level. To keep this optimal, I'm going
to change a couple of things. Firstly, I'm going to

00:24:30.559 see if a rectangle is visible within the transformed view at the
location of the

00:24:36.559 cell with a nominal width of one by one. What that means is at zoom
level one,

00:24:42.720 our cell is one pixel by one pixel. This changes automatically by
the transformed

00:24:48.320 view. If the cell is visible, then I'm going to draw using the GPU
a rectangle

00:24:54.640 scaled and transformed by the transformed view at the cell's
location. Since I'm now drawing everything using

00:25:00.880 decals and on the GPU, they will disappear every frame. So, I don't
need to clear the screen. That will save us

00:25:06.880 some important CPU cycles. You may have noticed this draw count
variable. Well, I'm using that to keep track of how many

00:25:13.440 things I'm drawing on the screen at any one time because I'm also
going to display some useful metrics just to see

00:25:19.760 how things are going. So, I'm going to draw string detail how many
active cells

00:25:25.440 out of how many in the potential set and how many are actually
drawn. And let's

00:25:30.880 take a look. So, I've zoomed in a little bit and I'm clicking.
There we go. Notice we've got one active cell, but

00:25:36.400 that one active cell has the potential to change nine neighbors
including itself. So that 3x3 region around the

00:25:44.320 cell. If I change this now into the Oh, I've done it again, haven't
I? The R pentonimo shape. I'll just disappear.

00:25:51.039 Let's try that again. There we go. That one. And do a bit of
simulation where

00:25:56.640 you can see it exploded with growth. I can use the mouse wheel to
change the zoom and pan. There we go. and it threw

00:26:03.360 out those streamers which just keep going and going and going. We
can see that the amount of activity has now

00:26:09.600 become stable. And so every epoch of simulation there are 116
active cells,

00:26:15.360 but there are potentially 284 that can change. Let's add some
interference for these

00:26:22.000 two. Oh, it missed. Let's try again. With my single mouse clicks
and drawing like this, I can't cause enough

00:26:28.159 immediate damage. They look like they're effectively disappearing
because as I draw a line here, as we zoom in, we can

00:26:34.799 actually see that most of them just exist in isolation, which means
they'll get lonely and then die on the next

00:26:41.039 iteration. We can help with this by moving to a higher resolution
and using a 1:1 pixel ratio. Now, when I draw a

00:26:47.919 line and zoom in, it is indeed a line. So, let's simulate that.
Let's try again. Try and draw a straight line as

00:26:54.240 possible. There we go. Now, I've got a little streamer going off
here. So, let's run some interference against this

00:27:00.159 thing. So, now you can start to see still lots of empty space
there. Um, oh,

00:27:05.440 it actually shot right through them. The second one didn't, though.
That's good. Lots of activity going on. Now, those streamers will just go off
into space.

00:27:11.919 Look at that. Because having my infantessimly small mouse cursor in
an infinite universe makes it very

00:27:18.640 difficult to stimulate the cells. Conveniently, I'm going to add a
much biggier paintbrush to do things with.

00:27:25.039 That's the last bit of code to add. In pretty much the same code
for the left mouse button, I'm going to add some

00:27:30.880 sensitivity to the right mouse button, but this time it draws a
100x 100

00:27:36.159 rectangle of randomly generated cells. This allows me to add a lot
more stimulation into the system. So, if I

00:27:42.799 right click, there we go. That looks like all the cells have been
filled up. I'm going to start the simulation. And look at that. Isn't that very
nice? Very

00:27:50.640 pretty. And we can draw them like that. Much nicer.

00:27:57.520 can zoom right in. Let's zoom right back out. And because we're not
really limited by space anymore, we can do some

00:28:04.159 simulation up here this time. Now, the frame rate does take a hit.
It is now entirely based on how much activity

00:28:10.720 there might be per epoch and also the overhead of drawing all of
these thousands of rectangles per frame. As

00:28:17.600 the cells die off and leave lots of empty space behind, there's no
residual computation that needs to be performed.

00:28:24.399 It's quite nice that way that the algorithm is sort of
self-organizing itself in terms of what to do next. It'd

00:28:30.960 be really cool to uh do some very very large simulations like this.
But before

00:28:36.159 we can start thinking about very large simulations, we have to
address the elephant in the room. At the start of

00:28:41.600 this video, I showed a 1 megapixel image being simulated. That was
a whole 1

00:28:47.760 million game of life cells being updated at 30 frames pers. Here we
can see we've

00:28:53.840 only got 9,000 cells active and we're running at 38 frames pers. So
yes,

00:29:00.240 whilst the simulation can be unfathomably large, we're actually
paying quite a lot of performance

00:29:06.960 penalty to have that size. What could be the cause of this? Well,
it's more than

00:29:12.320 likely a fairly sloppy implementation of the unordered set. We're
doing a lot of

00:29:17.840 memory manipulations, insertions, and extractions, and then moving
memory around as part of our process in order

00:29:24.559 to represent this locationfree state space. We're also relying on a
single

00:29:30.480 core to do absolutely everything. Now, because I know some of you
will be

00:29:35.600 curious, I did have a look at how you could go about making this
multi-threaded to get even more performance out of it, and it does kind

00:29:42.799 of work, although the results are not as satisfactory as I'd have
hoped. I threw in the quick and dirty OM or OpenMP

00:29:49.840 parallelization library for C++. It actually makes going through
loops very

00:29:55.520 CUDA like is that you can tell the compiler to automatically
generate a bunch of threads to execute portions of

00:30:02.080 this loop in parallel. And the loop is exactly what we've just had
before. To manage that, the sets needed to be

00:30:08.000 broken up slightly because the algorithm is fundamentally data
reading. That's okay. Hey, we're not going to get lots

00:30:14.320 of clashes. But we do need to output the next epoch set without
collisions. So

00:30:19.679 each thread by OM goes away and does that uh by using this thread
identity

00:30:24.720 value in an array of sets and at the end of the algorithm the sets
are all merged together. However, this merging

00:30:31.600 operation is quite timeconuming and in fact makes all of this
process a little bit redundant. I've not given up on this

00:30:38.240 however and I'm going to explore it a bit further. And so there you
have it. Conway's Game of Life, but with a pretty

00:30:43.760 much infinite simulation space. I think it's very fascinating, and
I know that there are some very large Conway game of

00:30:49.919 life models out there, which would be interesting to import and
simulate using this tool. Now, I know there's not been

00:30:55.520 that many videos this year, and I've got a reason for that, and
that's coming up in a little review video uh shortly

00:31:01.120 because we've also got the OneLoda Jam coming up towards the end of
August, too. But as usual, if you've enjoyed

00:31:06.799 this video, a big thumbs up. Please have a think about subscribing.
Come and have a chat on the Discord. All those nerds

00:31:12.399 are still there. And I'll see you next time. Take care.

