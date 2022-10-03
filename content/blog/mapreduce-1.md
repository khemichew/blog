+++
title = "How MapReduce was created"
date = "2022-09-17T14:32:21+01:00"
tags = []
+++

I first came across MapReduce in a Software Engineering Design module 
offered in the second year of my course, and was stunned by the simplicity 
of the framework. It is highly scalable and adept at crunching
large input datasets that can be distributed across thousands
of machines, making it a great choice for processing parallelisable 
problems.

A Google search away shows that it has been widely adopted in many distributed 
systems - Hadoop, CouchDB, and Spark are but a few of many implementations 
available to the open-source community.

To understand how MapReduce was created, I wanted to understand the world of 1995 - 
a world before digital transformation took place that would go on to change 
the course of everyone's lives.

### The early days

In 1995, the World Wide Web had only been publicly accessible for
4 years, and it is estimated that only 0.05% of the world population were users 
of the Internet.[^fn1] The social media didn't exist yet. Most 
households did not even have a laptop or a smartphone - people were then using 
flip phones and brick phones and were communicating with each other primarily
using SMS and texts.

{{< image
src="/images/motorola_microtac.png"
alt="Motorola MicroTAC 9800X" 
caption="Motorola MicroTAC 9800X; the first of many MicroTAC models produced over nearly a decade since its introduction in 1989. (Ross Padluck via Wikipedia)" >}}

At Stanford, Larry Page and Sergey Brin came out with a great idea to 
create a rating system that could rank searches. They would utilise the 
existing hyperlinks on each site to build a structure of the web, and rank 
each site in the search results based on the number of hyperlinks that were 
pointed at the site. The algorithm, patented as PageRank, would later play 
a key role in skyrocketing Google to its success.[^fn2]

Many people started adopting Google to search the web, to the point it
would consume half of Stanford's Internet capacity. They grabbed plenty of 
free commodity hardware given to the university by the computer manufacturing 
companies to build custom server racks in their dorm. Page was also buying an
abundant amount of cheap, less reliable hard disk drives to store the millions
of sites they had crawled. It was an approach that Google would adopt in 
building infrastructure at low cost. 

### Building systems at scale

As the scale of the operation grew, Google would move out from Stanford and 
set up its base at Palo Alto as a startup after a brief stint at a modest garage. 
While they had roughly 80 commodity machines dedicated to crawl and index the 
Internet, they had the need to rapidly scale up to respond to the increasing hundreds 
of thousands of queries every day. Google would come to face a major hurdle in 2000, when 
the index of the search engine, key to locating relevant documents for a search query, 
wouldn't update.

{{< image
src="/images/google_1999.png"
alt="Google in Palo Alto, 1999"
caption="Google's first office in Palo Alto during 1999. (Google via Twitter)" >}}

The search engine indexing process had a design flaw - if a machine broke down 
during the middle of the crawl, indexing wouldn't continue and had to be done 
from scratch. The single point of failure, magnified by the increased probability
of failures induced by less reliable hardware, would stop the search engine
from updating its results with fresher and more relevant content from the web.

To solve this problem, the engineers had to rethink the way the system was built.
They had to build a system that embraced the philosophy of tolerating frequent 
failure of components. This led to the design of a new file system, Google File
System (GFS)[^fn3], that could automate failure recovery by introducing redundancy. 

> Actually, at that time, the web was growing to be a big deal, and people are
> building big websites. In addition, there had been decades of research into 
> distributed systems, and people sort of knew at least on the academic level
> how to build all kinds of highly parallel, fault-tolerant systems, but there had
> been very little use of academic ideas in [the] industry. But starting at around
> this time [2004] this paper was published, big websites like Google started to
> build serious distributed systems, and it was very exciting for people like me
> to see real uses of these ideas. - Robert Morris[^fn4]

### Designing MapReduce

For a while, the engineers had followed the approach of manually handwriting 
the software to distribute the problem they were working on to the cluster they
were running. This would require laborious effort to find ways to break down
the computation into subtasks, send it to the farm of machines in the data centers,
and somehow find a way to organise the result of the computation. 

To enable the other engineers to just write the logic of the analysis they wanted
to compute without having to worry about the intricacies of distributed systems,
Jeffrey Dean and Sanjay Ghemawat designed MapReduce. MapReduce made it easy for
engineers to write software that could crunch giant datasets and compute results 
by just writing a Map and a Reduce function; the framework would then take care
of everything else. 

By the time the MapReduce paper[^fn5] had been released, hundreds of MapReduce programs
had been implemented and upwards of one thousand MapReduce jobs are executed on
the clusters every day. 

MapReduce was in some sense hugely successful, for it 
allowed Google to harness the huge computation resource they had with commodity
machines via a simple and powerful interface that enables automatic parallelisation
and distribution of large-scale computations, built upon the philosophy of 
embracing frequent component failures, locality optimisation of reading data
from local disks offered by GFS, the understanding of the engineers to 
decouple the logic of computation from the behemoth of complexity that is distributed 
systems, and having the key insight on data transformation, in which sorting is
better than hashing.[^fn6]


[^fn1]: The data on internet users in 1990 is archived on Worldmapper: 
http://archive.worldmapper.org/textindex/text_communication.html 

[^fn2]: Tale adapted from _In the Plex: How Google Thinks, Works, and Shapes Our Lives_.
Interesting read if you want to find out the inside story about Google!

[^fn3]: Google File System paper: https://static.googleusercontent.com/media/research.google.com/en//archive/gfs-sosp2003.pdf

[^fn4]: Robert Morris teaches 6.824: Distributed Systems at MIT every spring. 
This quote can be found in his lecture on GFS at https://www.youtube.com/watch?v=cQP8WApzIQQ&t=3498s.

[^fn5]: MapReduce paper: https://static.googleusercontent.com/media/research.google.com/en//archive/mapreduce-osdi04.pdf

[^fn6]: Read Oscar Stiffelman's account on why MapReduce is so effective:
https://medium.com/@oscarstiffelman/a-brief-history-of-mapreduce-97aec97df8ff