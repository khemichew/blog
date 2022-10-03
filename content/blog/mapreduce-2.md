+++
title = "The inner workings of MapReduce"
date = "2022-09-18T14:26:20+01:00"
tags = []
+++

In essence, MapReduce is about analysing data by applying the _split-apply-combine_
strategy, inspired by the map and reduce functions commonly used in functional programming.
It is best used when a problem can be broken down into subtasks that can be 
independently solved, so the computation power of a cluster of machines can be 
harnessed to execute MapReduce tasks concurrently.

### A programmer's point of view
 
To use MapReduce, a programmer needs to supply a map and a reduce (pure) function to the framework.

The `Map` function takes in a key and a value, and returns a list of key-value pairs
possibly of a different type from the original key and value pair. The function signature
of the map function looks like this, given types `A`, `B`, `C`, `D`:

```go
fn Map(A k1, B v1) -> List((C k2, D v2))
```

The `Reduce` function takes in a key and a list of values, and returns
a list of key-value pairs, which has the following function signature given type `E`:

```go 
fn Reduce(C k2, List(D v2)) -> List(E v)
```

In practice, MapReduce implementations specify all types as `string` to achieve a generalised
interface; the programmer would have to modify the input and output as string
representations into its actual representation before processing the data.

### Example

A sample program solving the problem of word counting in a large collection of
documents may look like this:

```go
// key = document name, value = document contents
fn Map(string key, string value):
  for word in value:
    return (word, "1")
```

```go
// key = word, values = a list of word counts
fn Reduce(string key, list(string) values):
  return [string(len(values))]
```

The programmer can also decide what the form of output the reduce function would be:
for example, in a count of URL across frequency computation, the reduce function
may add together all values for the same URL and emits a (URL, total count) pair 
instead of a single value per the word count program example.

### Usage

A common way to use the MapReduce framework is to chain multiple jobs, feeding the 
output of a MapReduce job to the input of another MapReduce job (the whole
computation is a job made up of multiple map tasks and reduce tasks).
This is replicated in other systems such as Hadoop, and particularly Spark, which is effective at dealing
with chains of parallel operations by using iterative algorithms, making it an 
excellent choice for machine learning computations.

Note that it is not necessary but not sufficient to implement map and reduce functions
to use the framework - it may also require setting up a way to distribute input, 
intermediate and output data across a cluster of machines. The MapReduce paper achieves this by
utilising GFS, where MapReduce and GFS runs on the same set of nodes, 
allowing each node to read in the fractionalised input data locally.
However, a programmer is not limited to using a distributed file system as the
setup - different approaches such as direct streaming from mappers to reducers, or
mapping processors to serve their results to reducers that query them are viable too.

### A maintainer's point of view

As a maintainer, one would need to design a system that can perform the distributed
processing of the map and reduction operations. A simple model of MapReduce can be 
described by a master node and a set of worker nodes. The master node will have to 
create the tasks for map and reduce operations, assign them to worker nodes, 
keep track of each task's progress and reassign them in case a worker fails or 
takes too long to respond. 

On the other hand, each worker node will follow a set of operations. Assuming that
each worker has the input files locally, it will run the map function exactly once 
for each key before requesting another map task from the master, repeating this 
step until all map tasks are exhausted. 

Once the map phase is complete, the master node will shuffle the data through
the network to the workers responsible to execute reduce tasks by organising
the delivery of map function outputs to the relevant worker nodes. 
Optimised, well implemented shuffling is a key factor to the performance of the 
MapReduce framework. 
The worker then applies the reducer to the output of the map function and sorts
the final output before reporting the task completion to the master node.

### Revisiting the word count problem

{{< image
src="/images/mapreduce_explain_1.png"
alt="Contents of each file"
caption="" >}}

Imagine we have a set of three webpages crawled from the web,
and we want to obtain the word count for each document using the MapReduce
framework. The contents of the file are as shown above:

{{< image
src="/images/mapreduce_explain_2.png"
alt="Map phase"
caption="" >}}

The framework will run the map function on each input file and produce
a list of key-value pairs as an intermediate output, ready to be passed into
the reduce task. Here, the key is the word, whereas the value is the count - in 
all cases, each word is mapped to one as its value.

{{< image
src="/images/mapreduce_explain_3.png"
alt="Shuffling phase"
caption="" >}}

Instances from all maps are then collected and allocated to a particular reduce
task input based on the partitioning function for sharding purposes. The partition
function is given the key and the number of total reduce tasks, which returns the
index of desired reducer.

A common partitioning approach would be hashing the key and using the hash value
modulo the number of total reduce tasks. It is important to pick a partition function
so the values in each bucket are approximately equal, so as to balance the load 
between different worker nodes and reduce the likelihood of a straggler delaying 
the completion of MapReduce operation. The paper also discusses a general 
mechanism to alleviate the problem of stragglers. The implementation would have the master 
node scheduling backup executions of the remaining in-progress tasks when a 
MapReduce operation is close to completion. This significantly reduces the 
time to complete large MapReduce operations. 

{{< image
src="/images/mapreduce_explain_4.png"
alt="Reduce phase"
caption="There may be different keys residing in the same bucket. The framework tackles this by sorting the data by key using the application's comparison function." >}}

Finally, the framework calls upon the reduce function for each entry in sorted order,
producing zero or more outputs depending on the implementation of the function. 
The final result of the word count MapReduce operation would be:

```go
A 2
B 2
C 1
```

Wew, that was a really long-winded article! In my next article, I shall discuss my 
attempt to implement a simpler version of MapReduce that runs on a single computer.