
from jujuclient import Environment

env = Environment.connect("test")

watcher = env.watch()

out = env.add_machine("trusty","cpu-cores=1")
print out
for change_set in watcher:
    print change_set
