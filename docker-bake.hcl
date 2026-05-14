variable "TAG" {
  default = "latest"
}

# Common settings for all targets
target "common" {
  context = "."
  platforms = ["linux/amd64"]
  args = {
    BUILDKIT_INLINE_CACHE = "1"
  }
}

# Regular ComfyUI image (CUDA 12.4, PyTorch 2.7.0 stable)
target "regular" {
  inherits = ["common"]
  dockerfile = "Dockerfile"
  tags = ["madiator2011/better-comfyui:${TAG}"]
}

# RTX 5090 optimized image (CUDA 12.8, PyTorch 2.7.0 stable cu128)
target "rtx5090" {
  inherits = ["common"]
  dockerfile = "Dockerfile.5090"
  tags = ["madiator2011/better-comfyui:${TAG}-5090"]
}
