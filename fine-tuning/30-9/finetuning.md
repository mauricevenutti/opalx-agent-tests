
# Internalizing stable domain knowledge through adapter fine-tuning

Retrieval agumented generation is an exact look up of text chunks, but expensive for the agent. Every call puts several raw chunks into its context window. "Stable knowledge" like how the codebase is organized should not be rederived in every session, we aim to train a small (fine-tuned) expert model who internalized this knowledge at training time, and returns short answers during a session. 


### Stable Knowledge 

- **Code Conventions**: naming, directory layout, class patterns, error handling and logging idions. 
- **Physics**: units, normalizations, coordinate frames
- **Input deck semantics:** not sure about this one
- **Dev worklfow:** also maybe too specific for a codebase
- **Numerics:** why a method was chosen. Its stability and accuracy limits, known pitfalls
- **framework idioms** how the codes uses libaries it is built on (data declarations, loops, host vs device memory, parallel decompositions, particle-grid coupling)
- **Defer pairs**

### Specific knowledge
This is knowledge that should be retireved: 
- code snippets, line numbers, default values, behaviour that changed between versions, recent issues, anything that need citation


### Routing

We can extend this later with other techniques

The agents sees the two tools and their description `ask_expert_mcp`for conventions, structure and why-questions. The `science_mcp` for exact, version-specific or citable facts. The agent chooses per look up or follows the user's mode. The expert returns an answer (and maybe a confidence metric? -> low confidence -> use `science_mcp`). Both paths leave evidence cards in the ledger for traceability (e.g. training commit of the adapter).   


### Training data

A training example has **Instruction** = the question the main agent would send to ask_expert, **Input** = the context the agent sends along (its code or a deck fragment; often empty), and **Response** = the expert's answer.

For example (from LLM memory generated, do not use these)


1. Framework Idiom**
```
### Instruction:
Is this the right way to rescale particle charges in OPALX? If not, fix it.

### Input:
auto Qview = bunch->Q.getView();
for (size_t i = 0; i < bunch->getLocalNum(); ++i) {
    Qview(i) *= weight;
}

### Response:
No. Particle attributes live in Kokkos views that may be in GPU memory, so a plain
host-side for-loop is wrong on device builds (it crashes or silently touches host
memory). Loops over particles are written as Kokkos parallel kernels over the local
particle count, with views captured by value:

auto Qview = bunch->Q.getView();
Kokkos::parallel_for("scale_charge", bunch->getLocalNum(),
    KOKKOS_LAMBDA(const size_t i) { Qview(i) *= weight; });

Only local particles are touched, so no MPI communication is needed. If host code reads
Q right after, call Kokkos::fence() or copy to a host mirror first.

```

2. Input-deck semantics, no Input

```
### Instruction:
In an OPALX input file, what decides when tracking stops?

### Input:

### Response:
Tracking is set in the TRACK block. It stops at whichever limit is reached first: the
maximum number of steps (MAXSTEPS) or the longitudinal stop position (ZSTOP). A common
mistake is setting ZSTOP past the end of the lattice while leaving MAXSTEPS small; the
run then ends early without an error. Check both when a run seems too short.

```


3. Physics 

```
### Instruction:
What units does OPALX expect for the RF cavity attributes?

### Input:
CAV1: RFCAVITY, L=0.2, VOLT=?, FREQ=?, LAG=?;

### Response:
Lengths are in metres, VOLT is the peak voltage in MV, FREQ is in MHz and LAG is the
phase in radians. Giving FREQ in Hz (off by 10^6) or LAG in degrees are the usual
mistakes; neither raises an error, they just change the physics.
```


4. Numerics 

```
### Instruction:
Why is space charge solved with an FFT on a doubled grid instead of the plain grid?

### Input:

### Response:
The bunch sits in free space, so the Poisson problem has open boundary conditions. An
FFT on the plain grid would impose periodic ones, and the bunch would feel image
charges from its periodic copies. Hockney's method zero-pads the charge density to a
grid twice as large in each dimension and convolves with the free-space Green's
function, which removes those images. The cost is 8x the memory of the field grid in
3D, which is why grid size is the main memory knob for space-charge runs.

```


5. Defer pair (teaches the expert what not to answer)

```
### Instruction:
What arguments does the scatter function take, and in which order?

### Input:

### Response:
DEFER: version-specific. Exact signatures change between IPPL/OPALX versions.
science_mcp query: "scatter function signature ParticleAttrib field positions"
Stable part: scatter deposits a particle attribute (e.g. charge) onto a mesh field
using the particle positions; gather does the reverse.
Keep the defer format fixed (DEFER: + a suggested query) so the router can parse it and fall back to retrieval automatically. A defer can still include the stable part of the answer, so the agent often only needs a small targeted lookup.

````

6. Paraphrases of one fact (same Response, different Instructions)

```

"Why does my OPALX run crash on GPU but not CPU when I loop over particles?"
"How should I write a loop over all particles in OPALX?"
"Can I use a normal for-loop to update particle momenta?"
```

Record disk: 

````
{"instruction": "...", "input": "...", "output": "...",
 "category": "framework_idiom", "defer": false,
 "source": {"repo": "OPALX", "file": "...", "lines": "120-164", "commit": "a1b2c3d"},
 "teacher": "model-id", "grounding_check": "pass"}

 ```

 Training: mask questions and input tokesn, so model learns to produce answers. Depending on what model we use we may change the template


 