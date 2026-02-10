//+------------------------------------------------------------------+
//|                                                       ob_opencl.mqh
//|  OpenCL helpers / toggle for legacy mode
//+------------------------------------------------------------------+
// Toggle OpenCL support: set to 1 to enable OpenCL paths, 0 for legacy CPU-only
#ifndef USE_OPENCL
#define USE_OPENCL 0
#endif

// Helper: check at compile-time / toggle time
// When USE_OPENCL==1 you are expected to provide real OpenCL initialization
// and kernel calls in the places annotated in the codebase below.
inline bool IsOpenCLEnabled()
  {
#if USE_OPENCL
   return(true);
#else
   return(false);
#endif
  }

// Notes for integration:
// - MQL5 provides an OpenCL interface (OpenCLCreateContext, OpenCLBuildProgram, etc.).
// - For each annotated loop in the orderBlock folder consider:
//     * collecting the input arrays into contiguous buffers
//     * creating an OpenCL kernel that performs the per-element work or reduction
//     * enqueueing the kernel and reading back results
// - Keep the legacy path (IsOpenCLEnabled()==false) untouched so published EA continues working.

// Example usage pattern (pseudocode):
// if(IsOpenCLEnabled()) { run_opencl_kernel(...); } else { fallback_cpu_loop(...); }
