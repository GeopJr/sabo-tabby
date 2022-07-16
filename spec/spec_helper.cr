require "spec"
require "../src/sabo-tabby"

COLORS_ENABLED = STDOUT.tty? && STDERR.tty? && ENV["TERM"]? != "dumb"

# Disable colorize only for the block and then reset to original value.
def disable_colorize(&block)
  Colorize.enabled = false
  result = yield
  Colorize.enabled = COLORS_ENABLED

  result
end

# Override abort so it doesn't exit.
def abort(message = nil, status = 1)
  message
end
