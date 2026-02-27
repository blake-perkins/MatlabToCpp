from conan import ConanFile
from conan.tools.cmake import CMake, CMakeToolchain, CMakeDeps, cmake_layout


class SensorPipelineApp(ConanFile):
    name = "sensor_pipeline"
    version = "1.0.0"
    license = "Proprietary"
    description = "Example application chaining kalman_filter, low_pass_filter, and pid_controller"
    settings = "os", "compiler", "build_type", "arch"
    exports_sources = "CMakeLists.txt", "src/*"

    def requirements(self):
        self.requires("kalman_filter/[>=0.1.0]")
        self.requires("low_pass_filter/[>=0.1.0]")
        self.requires("pid_controller/[>=0.1.0]")

    def generate(self):
        tc = CMakeToolchain(self)
        tc.generate()

        deps = CMakeDeps(self)
        deps.generate()

    def layout(self):
        cmake_layout(self)

    def build(self):
        cmake = CMake(self)
        cmake.configure()
        cmake.build()
