+++
title = "My attempt at recreating MapReduce"
date = "2022-10-03T23:38:12+01:00"
tags = []
+++

MIT 6.824 has a set of lab exercises conducted in Go that are conducive for learning distributed 
systems in a hands-on manner, which I will use to start building a MapReduce
system.[^fn1] The skeleton provided is set up in a way such that there is a coordinator (master)
process that hands out tasks to worker processes and copes with failed workers.
The worker process will call the application Map and Reduce functions and handles
reading and writing files. 

### Project outline

The project is roughly divided into six sections:
- implementing the data structure to track task status in the master process;
- keeping master up-to-date with task distribution state across different worker processes;
- processing map phase on worker processes;
- shuffling the map function output;
- processing reduce phase on worker processes;
- and building fault-tolerant and failure recovery measures.

### Implementing the data structure
The master has up-to-date information about progression of each task (otherwise, it 
would not know how to allocate tasks to the workers). Considering that multiple 
workers may try to acquire a new task from the master at the same time, we need to
make sure the `Coordinator` data structure is thread-safe.

#### First try: the straightforward approach
A naive way to store the state of each task is to create a list containing 
the task type, task progress, only accessible via a lock:

```go {linenos=table}
type Coordinator struct {
    sync.Mutex
    // ------- CRITICAL SECTION -------
    state []*Task
    // --------------------------------
}

type Task struct {
    Type TaskPhase
    Progress TaskProgress
    Id int
    // and more...
}
```

Each task is uniquely identified by its current phase and an `id` number (one could also make `id` the sole identifier, 
but is not done here in the interest of clarity). The keen-eyed may notice that searching for a task in the list will
take O(N) time, as does checking which tasks fulfil a specified condition, since we need to iterate through the entire 
list.

#### Second try: the efficient approach
We could try and adapt from the LRU(Least Recently Used) cache data structure[^fn2] to speed up the lookup. 
To achieve O(1) time complexity for operations required, I modified the data structure as follows:

```go {linenos=table}
type Coordinator struct {
	sync.Mutex
	// ------- CRITICAL SECTION -------
	mapTasks    *Tasks
	reduceTasks *Tasks
	// --------------------------------
}

type Tasks struct {
	// [IdleQueue, InProgressQueue, CompletedQueue]
	Queue map[Progression]*list.List
	// maps Task.TaskId to individual node containing Task.
	Node map[int]*list.Element
	// maps Task.TaskId to one of Idle, InProgress, or Completed.
	State map[int]Progression
	// Number of total tasks. Constant once initialised.
	Capacity int
}

type Task struct {
	// One of MapTask, ReduceTask, VoidTask, ExitTask.
	Phase Phase
	// Input filepath. Only applicable for map tasks.
	InputFilepath string
	// Unique identifier for each task.
	TaskId int
	// Identifies Worker executing the task.
	WorkerId int
}
```

Although elaborate, it allows O(1) time complexity for searching tasks by looking up the hashmap 
via `TaskId`. We can also check for completion of a MapReduce phase by simply checking the length of
list of `State[Completed]` equalling the total number of tasks assigned in that phase.

### Keeping master up-to-date with state of all tasks

With the data structure implemented, we turn to the problem of coordinating data between different nodes.
There are two strategies that can be adopted in coordinating tasks between the
master and the workers - the first one involves having the worker register itself
with the master and have the master send tasks to each worker to be executed. This approach allows
the master to periodically check if each worker is still alive, and actively
reschedule the task if the worker does not respond to pings sent by the master.

I went with another approach instead - the worker will request tasks from the
master and report each task once the computation for map or reduce function is
complete. Since the lab is designed to only run on a local machine, we will make 
use of RPC to allow nodes (processes) to talk to each other. 

Note that many workers may contact the master concurrently so every RPC call must
acquire the lock before beginning to poll the next task to be worked on.

### Processing map tasks

The key idea to process a map task is to read the input file assigned by the master (in the original
implementation, the input would have been divided into chunks of smaller fixed-size files), apply the
map function provided by the user on the data, and partition the results into a given number,
`nReduce`, of intermediate files, which will be specified by the user.

```go {linenos=table}
func doMap(task *WorkerTask, mapf func(string, string) []KeyValue) {
	...

	// Apply map function
	kva := mapf(task.InputFilepath, string(content))

    ...
}
```

### Shuffling the map function output

Assigning which data to which reduce task can be done by hashing: we apply the `ihash` function
and modulo it with the total number of intermediate files we want to create/number of reducers (`r`), 
in the form of "mr-task-`i`", where `i` is in range [0, `r`). Hence there will be at most `r` files
created - this information will be useful later on when we want to read the intermediate file for the 
reduce tasks.

To block users from accessing partially written files during the execution of the job or in the event
of a crash, we also create temporary files at the start and rename them atomically to the intermediate
filenames.

```go {linenos=table}
func doMap(task *WorkerTask, mapf func(string, string) []KeyValue) {
	...

	for _, kv := range kva {
		partition := ihash(kv.Key) % task.TotalReduceTask
		filename := fmt.Sprintf("mr-%d-%d", task.TaskId, partition)

		// Create temporary files so user cannot observe partially
		// written file in the presence of a crash
		if _, ok := files[filename]; !ok {
			temp, err := os.CreateTemp("", filename)
			...
			files[filename] = temp
		}

		// Append to file
		enc := json.NewEncoder(files[filename])
		err := enc.Encode(&kv)

		...
	}

	// Atomically rename files
	for filename, temp := range files {
		...
		err := os.Rename(temp.Name(), filename)
		...
	}
}
```

### Processing reduce tasks

This is similar to processing map tasks - it merges all data that would have been
shuffled into intermediate files that are assigned to the current worker, and applies
the user-supplied reduce function. Finally, it stores the results in a single output file.

The tricky part is to notice the partition number produced by the hash function, `i`, may not 
cover the entire range of [0, `m`], where `m` is the number of mapped files, in the 
intermediate filenames "mr-`i`-task`. I used regular expression to match the files explicitly:

```go {linenos=table}
func doReduce(task *WorkerTask, reducef func(string, []string) string) {
	...
	
	// Filter irrelevant inputs
	for _, file := range matchingFiles {
		pattern := fmt.Sprintf("mr-([0-9]+)-%v", task.TaskId)
		if match, _ := regexp.MatchString(pattern, file); match {
			intermediate = append(intermediate, file)
		}
	}
	
	...
}
```

In practice, it is better to limit the range directly from 0 to `m`, which will target
only the relevant files.

The same trick to write data into intermediate files - renaming files atomically - is also employed here
to create the resulting output file.

Also note that we sort the data by key to produce the final outcome:

```go {linenos=table}
func doReduce(task *WorkerTask, reducef func(string, []string) string) {
    ...
    
    // Sort key-value pair in map
        var keys []string
        for k := range kva {
            keys = append(keys, k)
        }
        sort.Strings(keys)
        
   ...
}
```

### Crash recovery

The current approach, however, does not allow for the master to initiate contact
with the workers and check if they are still "alive". The master has no way to
differentiate if a worker has crashed, stalled, or is executing too slowly to be useful.

Instead, we start a thread that counts down in the background for an amount of time after a 
task is assigned to a worker. If the worker does not respond and timeouts, the task will be
reassigned to another worker node: 

```go {linenos=table}
// Countdown until time expires and check task status. 
// If task is incomplete, the coordinator reschedules the task.
func (c *Coordinator) waitTask(phase Phase, taskId int) {
	if !(phase == MapTask || phase == ReduceTask) {
		return
	}

	// Wait for timeout seconds
	<-time.After(time.Second * Timeout)

	c.Lock()
	defer c.Unlock()

	// Timeout: reset task to idle state
	tasks := c.getTasks(phase)
	if tasks.State[taskId] == InProgress {
		tasks.UpdateTaskState(taskId, Idle)
		tasks.SetWorker(taskId, -1)
	}
}
```

And that's a wrap! You may view the repository at https://github.com/khemichew/MapReduce and
look at how each component interacts with one other to make this project work. 

[^fn1]: https://pdos.csail.mit.edu/6.824/labs/lab-mr.html

[^fn2]: https://www.educative.io/m/implement-least-recently-used-cache