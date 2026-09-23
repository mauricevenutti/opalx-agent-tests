OPALX explicitly overrides IPPL and selects periodic particle boundaries for the ordinary `OPEN` solver.

The boundary-condition paths are separate:

```text
BCFFTX/Y/Z = OPEN
        ├── field layout / field halo BC → open
        └── particle layout BC           → periodic  ← mismatch
```

Root cause is [PartBunch.cpp](/Users/adelmann/git/opalx-beambeam/src/PartBunch/PartBunch.cpp:103):

```cpp
const ippl::BC particleBC =
    (useP3M && !isAllPeriodic) ? ippl::BC::NO : ippl::BC::PERIODIC;
```

Therefore:

- `P3M + OPEN` → `ippl::BC::NO`
- ordinary `OPEN + OPEN` → `ippl::BC::PERIODIC`
- `PERIODIC` → `ippl::BC::PERIODIC`

The selected value is passed to every primary and witness container at [PartBunch.cpp](/Users/adelmann/git/opalx-beambeam/src/PartBunch/PartBunch.cpp:127) and installed at [ParticleContainer.hpp](/Users/adelmann/git/opalx-beambeam/src/PartBunch/ParticleContainer.hpp:228).

Why this happened:

- Commit `71cca91ee`, “Implement open BC P3M,” added configurable particle BCs, but only enabled `NO` for P3M.
- The ordinary open Poisson solver retained the historical periodic default.
- Existing OPALX tests verify open versus periodic particle layouts only for P3M. There is no equivalent test for the standard `OPEN` solver.

Meanwhile, the field boundary is correctly open: [BCHandler.hpp](/Users/adelmann/git/opalx-beambeam/src/PartBunch/BCHandler.hpp:190) maps `OPEN` to `ippl::NoBcFace`. Thus the field and particle layouts currently disagree.

IPPL already supports the desired behavior:

- Its particle-layout default is `BC::NO`: [ParticleLayout.h](/Users/adelmann/git/opalx-beambeam/build_openmp/_deps/ippl-src/src/Particle/ParticleLayout.h:59).
- `setParticleBC(BC::NO)` is supported.
- During `update()`, `BC::NO` leaves coordinates unchanged, whereas `PERIODIC` wraps them: [ParticleLayout.hpp](/Users/adelmann/git/opalx-beambeam/build_openmp/_deps/ippl-src/src/Particle/ParticleLayout.hpp:49).
- On one rank, `update()` returns immediately after applying the selected BC. On multiple ranks, an out-of-domain particle remains on its current rank rather than being wrapped or deleted.

So the concise diagnosis is:

> `OPEN` can use `ippl::BC::NO`; OPALX simply never requests it for the ordinary open solver.

The likely correction is to derive particle BC from `isAllPeriodic`, independent of `useP3M`:

```cpp
const ippl::BC particleBC =
    isAllPeriodic ? ippl::BC::PERIODIC : ippl::BC::NO;
```
I quick fix is shown in efedfcc31

reply: 

Good catch. Just to be clear, this is not necessarily a bug, since OPALX has adaptive mesh bounds and therefore never runs into a case where it needs to apply particle container boundary conditions (that's why I never really cared about the particle-side flag when implementing the solvers). 

But nevertheless I think it's a semantical error and should be fixed (it might even save a few milliseconds per time step). The commit you linked looks good to me. Should I cherry pick it and make a PR?


reply:


> On 28 Aug 2026, at 11:25, Alexander ***@***.***> wrote:
> 
> 
> aliemen
>  left a comment 
> (OPALX-project/OPALX#534)
>  <https://github.com/OPALX-project/OPALX/issues/534#issuecomment-5450809561>
> Good catch. Just to be clear, this is not necessarily a bug, since OPALX has adaptive mesh bounds and therefore never runs into a case where it needs to apply particle container boundary conditions (that's why I never really cared about the particle-side flag when implementing the solvers).
> 
Apparently it is a bug when fixing one dimension i.e. make it non adaptable as I need for beam-beam :)


> But nevertheless I think it's a semantical error and should be fixed (it might even save a few milliseconds per time step). The commit you linked looks good to me. Should I cherry pick it and make a PR?
> 

Yes sure 

A 

> —
> Reply to this email directly, view it on GitHub <https://github.com/OPALX-project/OPALX/issues/534?email_source=notifications&email_token=AC2WFIZIWDECDAHI23AODHL5MFFW7A5CNFSNUABFM5UWIORPF5TWS5BNNB2WEL2JONZXKZKDN5WW2ZLOOQXTKNBVGA4DAOJVGYY2M4TFMFZW63VGMF2XI2DPOKSWK5TFNZ2KYZTPN52GK4S7MNWGSY3L#issuecomment-5450809561>, or unsubscribe <https://github.com/notifications/unsubscribe-auth/AC2WFI4KUYQDUG2Z7RTRAKT5MFFW7AVCNFSNUABGKJSXA33TNF2G64TZHMYTANZVGQ3DSMBTG45US43TOVSTWNJSG43DKOJVG43DDILWAI>.
> Triage notifications, keep track of coding agent tasks and review pull requests on the go with GitHub Mobile for iOS <https://github.com/notifications/mobile/ios/AC2WFI7CXBP46ICDGRRVIOL5MFFW7A5CNFSNUABFM5UWIORPF5TWS5BNNB2WEL2JONZXKZKDN5WW2ZLOOQXTKNBVGA4DAOJVGYY2M4TFMFZW63VGMF2XI2DPOKSWK5TFNZ2KUZTPN52GK4S7NFXXG> and Android <https://github.com/notifications/mobile/android/AC2WFI7WRRI3AF4WU77JSY35MFFW7A5CNFSNUABFM5UWIORPF5TWS5BNNB2WEL2JONZXKZKDN5WW2ZLOOQXTKNBVGA4DAOJVGYY2M4TFMFZW63VGMF2XI2DPOKSWK5TFNZ2K4ZTPN52GK4S7MFXGI4TPNFSA>. Download it today! 
> You are receiving this because you authored the thread.
> 

reply:

> Apparently it is a bug when fixing one dimension i.e. make it non adaptable as I need for beam-beam :)

That makes sense, it will lead to a bug when particles leave the layout boundary. But that sounds like there are particles in beam-beam "escaping" the layout? If that's true and you call e.g. scatter/gather on such a particle it will seg-fault. This might therefore happen when you use `ippl::BC::NO` with fixed grid and open solver. Meaning we have to make sure that all particles are inside the layout and perhaps keep this in mind if we encounter weird seg-faults 😅 

