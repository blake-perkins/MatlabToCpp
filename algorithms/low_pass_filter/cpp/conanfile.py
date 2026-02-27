from conan import ConanFile
from conan.tools.cmake import CMake, CMakeToolchain, CMakeDeps, cmake_layout
import os


class LowPassFilterConan(ConanFile):
    name = "low_pass_filter"
    license = "Proprietary"
    description = "Low-pass filter algorithm (auto-generated from MATLAB via MATLAB Coder)"
    settings = "os", "compiler", "build_type", "arch"
    exports_sources = "CMakeLists.txt", "*.cpp", "*.h"

    def set_version(self):
        """Read version from the VERSION file."""
        version_file = os.path.join(
            os.path.dirname(__file__), "..", "VERSION"
        )
        if os.path.exists(version_file):
            with open(version_file) as f:
                self.version = f.read().strip()
        else:
            self.version = "0.0.0"

    def requirements(self):
        self.test_requires("gtest/1.14.0")
        self.requires("nlohmann_json/3.11.3")

    def generate(self):
        tc = CMakeToolchain(self)
        # Point to the generated code directory
        generated_dir = os.environ.get(
            "GENERATED_DIR",
            os.path.join(os.path.dirname(__file__), "..", "generated"),
        )
        tc.variables["GENERATED_DIR"] = generated_dir
        tc.variables["BUILD_TESTING"] = False  # Tests run separately in CI
        tc.generate()

        deps = CMakeDeps(self)
        deps.generate()

    def layout(self):
        cmake_layout(self)

    def build(self):
        cmake = CMake(self)
        cmake.configure()
        cmake.build()

    def package(self):
        cmake = CMake(self)
        cmake.install()

    def package_info(self):
        self.cpp_info.libs = [self.name]
        self.cpp_info.includedirs = [
            os.path.join("include", self.name)
        ]
