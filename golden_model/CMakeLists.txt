cmake_minimum_required(VERSION 3.10)
project(opencvtest VERSION 0.1.0)

include(CTest)
enable_testing()

find_package(OpenCV REQUIRED)
include_directories(${OpenCV_INCLUDE_DIRS})

# Create executable for main.cpp
add_executable(opencvtest_main main.cpp)
set_target_properties(opencvtest_main PROPERTIES CXX_STANDARD 17 CXX_STANDARD_REQUIRED YES)
target_link_libraries(opencvtest_main ${OpenCV_LIBS})

# On Windows: after build, copy any OpenCV DLLs found next to the linked libraries
# into the executable output directory (Release/Debug). This helps producing a
# runnable folder (exe + required DLLs) without requiring the user to install
# OpenCV in PATH or the Visual C++ redistributable immediately.
if(WIN32)
  # Collect DLLs that live in the same directories as the OpenCV libraries
  set(_opencv_dlls)
  foreach(_lib ${OpenCV_LIBS})
    # If the library is an imported target, try to get its imported location
    if(TARGET ${_lib})
      # Try common IMPORTED_LOCATION properties (multi-config support)
      get_target_property(_imp_loc ${_lib} IMPORTED_LOCATION_RELEASE)
      if(NOT _imp_loc)
        get_target_property(_imp_loc ${_lib} IMPORTED_LOCATION)
      endif()
      if(_imp_loc)
        get_filename_component(_libdir ${_imp_loc} DIRECTORY)
        file(GLOB _dlls_in_dir CONFIGURE_DEPENDS "${_libdir}/*.dll")
        foreach(_d ${_dlls_in_dir})
          list(APPEND _opencv_dlls "${_d}")
        endforeach()
        continue()
      endif()
    endif()

    # If OpenCV_LIBS entry is a path, try to use its directory
    if(EXISTS "${_lib}")
      get_filename_component(_libdir ${_lib} DIRECTORY)
      file(GLOB _dlls_in_dir CONFIGURE_DEPENDS "${_libdir}/*.dll")
      foreach(_d ${_dlls_in_dir})
        list(APPEND _opencv_dlls "${_d}")
      endforeach()
      continue()
    endif()
  endforeach()

  # Fallback: search common locations relative to OpenCV_DIR (if set)
  if(DEFINED OpenCV_DIR)
    # common layouts: <build>/lib/cmake/opencv4 -> binaries in <build>/bin or install/bin
    get_filename_component(_ocv_dir ${OpenCV_DIR} DIRECTORY)
    set(_search_dirs
      "${OpenCV_DIR}"
      "${_ocv_dir}/bin"
      "${_ocv_dir}/../bin"
      "${_ocv_dir}/../../bin"
      "${_ocv_dir}/../x64/vc*/bin"
      "${_ocv_dir}/x64/vc*/bin"
    )
    foreach(_sd ${_search_dirs})
      file(GLOB _dlls_from_ocv CONFIGURE_DEPENDS "${_sd}/*.dll")
      foreach(_d ${_dlls_from_ocv})
        list(APPEND _opencv_dlls "${_d}")
      endforeach()
    endforeach()
  endif()

  # Add a post-build copy command for each discovered DLL so they end up next
  # to the produced executable (works with multi-config generators).
  foreach(_dll ${_opencv_dlls})
    add_custom_command(TARGET opencvtest_main POST_BUILD
      COMMAND ${CMAKE_COMMAND} -E copy_if_different "${_dll}" $<TARGET_FILE_DIR:opencvtest_main>
      COMMENT "Copying ${_dll} to output folder"
    )
  endforeach()
endif()



set(CPACK_PROJECT_NAME ${PROJECT_NAME})
set(CPACK_PROJECT_VERSION ${PROJECT_VERSION})
include(CPack)
project(matplotlib_cpp LANGUAGES CXX)

include(GNUInstallDirs)
set(PACKAGE_NAME matplotlib_cpp)
set(INSTALL_CONFIGDIR ${CMAKE_INSTALL_LIBDIR}/${PACKAGE_NAME}/cmake)


# Library target
add_library(matplotlib_cpp INTERFACE)
target_include_directories(matplotlib_cpp
  INTERFACE
    $<BUILD_INTERFACE:${PROJECT_SOURCE_DIR}/examples>
    $<INSTALL_INTERFACE:include>
)
target_compile_features(matplotlib_cpp INTERFACE
  cxx_std_11
)
# TODO: Use `Development.Embed` component when requiring cmake >= 3.18
find_package(Python3 COMPONENTS Interpreter Development REQUIRED)
target_link_libraries(matplotlib_cpp INTERFACE
  Python3::Python
  Python3::Module
)
find_package(Python3 COMPONENTS NumPy)
if(Python3_NumPy_FOUND)
  target_link_libraries(matplotlib_cpp INTERFACE
    Python3::NumPy
  )
else()
  target_compile_definitions(matplotlib_cpp INTERFACE WITHOUT_NUMPY)
endif()
install(
  TARGETS matplotlib_cpp
  EXPORT install_targets
)

# Install headers
install(FILES
  "${PROJECT_SOURCE_DIR}/matplotlibcpp.h"
  DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})


# Install targets file
install(EXPORT install_targets
  FILE
    ${PACKAGE_NAME}Targets.cmake
  NAMESPACE
    ${PACKAGE_NAME}::
  DESTINATION
    ${INSTALL_CONFIGDIR}
)


# Install matplotlib_cppConfig.cmake
include(CMakePackageConfigHelpers)
configure_package_config_file(
  ${CMAKE_CURRENT_SOURCE_DIR}/cmake/${PACKAGE_NAME}Config.cmake.in
  ${CMAKE_CURRENT_BINARY_DIR}/${PACKAGE_NAME}Config.cmake
  INSTALL_DESTINATION ${INSTALL_CONFIGDIR}
)
install(FILES
  ${CMAKE_CURRENT_BINARY_DIR}/${PACKAGE_NAME}Config.cmake
  DESTINATION ${INSTALL_CONFIGDIR}
)
