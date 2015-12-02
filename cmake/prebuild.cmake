##
## Author: Hank Anderson <hank@statease.com>
## Description: Ported from OpenBLAS/Makefile.prebuild
##              This is triggered by system.cmake and runs before any of the code is built.
##              Creates config.h and Makefile.conf by first running the c_check perl script (which creates those files).
##              Next it runs f_check and appends some fortran information to the files.
##              Finally it runs getarch and getarch_2nd for even more environment information.

# CMake vars set by this file:
# CORE
# LIBCORE
# NUM_CORES
# HAVE_MMX
# HAVE_SSE
# HAVE_SSE2
# HAVE_SSE3
# MAKE
# SGEMM_UNROLL_M
# SGEMM_UNROLL_N
# DGEMM_UNROLL_M
# DGEMM_UNROLL_M
# QGEMM_UNROLL_N
# QGEMM_UNROLL_N
# CGEMM_UNROLL_M
# CGEMM_UNROLL_M
# ZGEMM_UNROLL_N
# ZGEMM_UNROLL_N
# XGEMM_UNROLL_M
# XGEMM_UNROLL_N
# CGEMM3M_UNROLL_M
# CGEMM3M_UNROLL_N
# ZGEMM3M_UNROLL_M
# ZGEMM3M_UNROLL_M
# XGEMM3M_UNROLL_N
# XGEMM3M_UNROLL_N

# CPUIDEMU = ../../cpuid/table.o

if (DEFINED CPUIDEMU)
  set(EXFLAGS "-DCPUIDEMU -DVENDOR=99")
endif ()

if (DEFINED TARGET_CORE)
  # set the C flags for just this file
  set(GETARCH2_FLAGS "-DBUILD_KERNEL")
  set(TARGET_MAKE "Makefile_kernel.conf")
  set(TARGET_CONF "config_kernel.h")
else()
  set(TARGET_MAKE "Makefile.conf")
  set(TARGET_CONF "config.h")
endif ()

include("${CMAKE_SOURCE_DIR}/cmake/c_check.cmake")

if (NOT NOFORTRAN)
  include("${CMAKE_SOURCE_DIR}/cmake/f_check.cmake")
endif ()

# compile getarch
set(GETARCH_SRC
  ${CMAKE_SOURCE_DIR}/getarch.c
  ${CPUIDEMO}
)

if (NOT MSVC)
  list(APPEND GETARCH_SRC ${CMAKE_SOURCE_DIR}/cpuid.S)
endif ()

if (MSVC)
#Use generic for MSVC now
set(GETARCH_FLAGS ${GETARCH_FLAGS} -DFORCE_GENERIC)
endif()

set(GETARCH_DIR "${PROJECT_BINARY_DIR}/getarch_build")
set(GETARCH_BIN "getarch${CMAKE_EXECUTABLE_SUFFIX}")
file(MAKE_DIRECTORY ${GETARCH_DIR})
try_compile(GETARCH_RESULT ${GETARCH_DIR}
  SOURCES ${GETARCH_SRC}
  COMPILE_DEFINITIONS ${EXFLAGS} ${GETARCH_FLAGS} -I${CMAKE_SOURCE_DIR}
  OUTPUT_VARIABLE GETARCH_LOG
  COPY_FILE ${PROJECT_BINARY_DIR}/${GETARCH_BIN}
)

message(STATUS "Running getarch")

# use the cmake binary w/ the -E param to run a shell command in a cross-platform way
execute_process(COMMAND ${PROJECT_BINARY_DIR}/${GETARCH_BIN} 0 OUTPUT_VARIABLE GETARCH_MAKE_OUT)
execute_process(COMMAND ${PROJECT_BINARY_DIR}/${GETARCH_BIN} 1 OUTPUT_VARIABLE GETARCH_CONF_OUT)

message(STATUS "GETARCH results:\n${GETARCH_MAKE_OUT}")

# append config data from getarch to the TARGET file and read in CMake vars
file(APPEND ${TARGET_CONF} ${GETARCH_CONF_OUT})
ParseGetArchVars(${GETARCH_MAKE_OUT})

set(GETARCH2_DIR "${PROJECT_BINARY_DIR}/getarch2_build")
set(GETARCH2_BIN "getarch_2nd${CMAKE_EXECUTABLE_SUFFIX}")
file(MAKE_DIRECTORY ${GETARCH2_DIR})
try_compile(GETARCH2_RESULT ${GETARCH2_DIR}
  SOURCES ${CMAKE_SOURCE_DIR}/getarch_2nd.c
  COMPILE_DEFINITIONS ${EXFLAGS} ${GETARCH_FLAGS} ${GETARCH2_FLAGS} -I${CMAKE_SOURCE_DIR}
  OUTPUT_VARIABLE GETARCH2_LOG
  COPY_FILE ${PROJECT_BINARY_DIR}/${GETARCH2_BIN}
)

# use the cmake binary w/ the -E param to run a shell command in a cross-platform way
execute_process(COMMAND ${PROJECT_BINARY_DIR}/${GETARCH2_BIN} 0 OUTPUT_VARIABLE GETARCH2_MAKE_OUT)
execute_process(COMMAND ${PROJECT_BINARY_DIR}/${GETARCH2_BIN} 1 OUTPUT_VARIABLE GETARCH2_CONF_OUT)

# append config data from getarch_2nd to the TARGET file and read in CMake vars
file(APPEND ${TARGET_CONF} ${GETARCH2_CONF_OUT})
ParseGetArchVars(${GETARCH2_MAKE_OUT})

function(ParseGetConfArchVarsOpenBLAS GETARCH_IN GETARCH_OUT)
  set(GETARCH_OUT_OPENBLAS)
  string(REGEX MATCHALL "#define [^\n]+[$\n]" GETARCH_RESULT_LIST "${GETARCH_IN}")
  string(REGEX REPLACE "\n" "" GETARCH_RESULT_LIST "${GETARCH_RESULT_LIST}")

  foreach (GETARCH_LINE ${GETARCH_RESULT_LIST})
    string(REGEX REPLACE " +" " " GETARCH_LINE_LIST "${GETARCH_LINE}")
    string(REGEX REPLACE "\t+" " " GETARCH_LINE_LIST "${GETARCH_LINE_LIST}")
    string(REPLACE " " ";" GETARCH_LINE_LIST "${GETARCH_LINE_LIST}")

    list(LENGTH GETARCH_LINE_LIST VAR_NUM)

    if(VAR_NUM EQUAL 2)
      list(GET GETARCH_LINE_LIST 1 VAR_NAME)
      set(GETARCH_OUT_OPENBLAS "${GETARCH_OUT_OPENBLAS}#define OPENBLAS_${VAR_NAME} \n")
    elseif(VAR_NUM EQUAL 3)
      list(GET GETARCH_LINE_LIST 1 VAR_NAME)
      list(GET GETARCH_LINE_LIST 2 VAR_VALUE)
      set(GETARCH_OUT_OPENBLAS "${GETARCH_OUT_OPENBLAS}#define OPENBLAS_${VAR_NAME} ${VAR_VALUE}\n")
    endif()
  endforeach ()

  set(${GETARCH_OUT} "${GETARCH_OUT_OPENBLAS}" PARENT_SCOPE)
endfunction ()


message(STATUS "Generating openblas_config.h in ${PROJECT_BINARY_DIR}")

file(READ ${TARGET_CONF} OpenBLAS_Config_Org_Str)
ParseGetConfArchVarsOpenBLAS("${OpenBLAS_Config_Org_Str}" OpenBLAS_Config_Str)

file(READ ${CMAKE_SOURCE_DIR}/openblas_config_template.h OpenBLAS_Config_Template_Str)

set(TARGET_OPENBLAS_CONF "${PROJECT_BINARY_DIR}/openblas_config.h")
file(WRITE ${TARGET_OPENBLAS_CONF} "#ifndef OPENBLAS_CONFIG_H\n#define OPENBLAS_CONFIG_H\n")
file(APPEND ${TARGET_OPENBLAS_CONF} "${OpenBLAS_Config_Str}")
file(APPEND ${TARGET_OPENBLAS_CONF} "#define OPENBLAS_VERSION \" OpenBLAS ${OpenBLAS_VERSION} \"\n")
file(APPEND ${TARGET_OPENBLAS_CONF} "${OpenBLAS_Config_Template_Str}")
file(APPEND ${TARGET_OPENBLAS_CONF} "#endif /* OPENBLAS_CONFIG_H */\n")


message(STATUS "Generating f77blas.h in ${PROJECT_BINARY_DIR}")

file(READ ${CMAKE_SOURCE_DIR}/common_interface.h OpenBLAS_common_interface_Str)

set(TARGET_f77blas_CONF "${PROJECT_BINARY_DIR}/f77blas.h")
file(WRITE ${TARGET_f77blas_CONF} "#ifndef OPENBLAS_F77BLAS_H\n#define OPENBLAS_F77BLAS_H\n#include \"openblas_config.h\"\n")
file(APPEND ${TARGET_f77blas_CONF} "${OpenBLAS_common_interface_Str}")
file(APPEND ${TARGET_f77blas_CONF} "#endif\n")

if(NOT NO_CBLAS)
  message(STATUS "Generating cblas.h in ${PROJECT_BINARY_DIR}")

  set(TARGET_cblasCONF "${PROJECT_BINARY_DIR}/cblas.h")

  file(READ ${CMAKE_SOURCE_DIR}/cblas.h OpenBLAS_cblas_Org_Str)
  string(REPLACE "common" "openblas_config" OpenBLAS_cblas_Str "${OpenBLAS_cblas_Org_Str}")
  file(WRITE ${TARGET_cblasCONF} "${OpenBLAS_cblas_Str}")
endif()

if(NOT NO_LAPACKE)
  message(STATUS "echo Copying LAPACKE header files to ${PROJECT_BINARY_DIR}")

  #set(TARGET_cblasCONF "${PROJECT_BINARY_DIR}/cblas.h")

  #file(READ ${CMAKE_SOURCE_DIR}/cblas.h OpenBLAS_cblas_Org_Str)
  #string(REPLACE "common" "openblas_config" OpenBLAS_cblas_Str "${OpenBLAS_cblas_Org_Str}")
  #file(WRITE ${TARGET_cblasCONF} "${OpenBLAS_cblas_Str}")
endif()
