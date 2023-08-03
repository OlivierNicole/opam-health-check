### How to install opam-health-check:

```
$ opam pin add opam-health-check .
```

### How to use opam-health-check locally:

For opam-health-check to work you need to start the server like so:
```
$ opam-health-serve --connect "$ocluster_cap" "$workdir"
```
For instance:
```
$ workdir=/tmp/opam-health-check
$ ocluster_cap="$HOME/ocluster.cap"
$ opam-health-serve --connect "$ocluster_cap" "$workdir"
```

Now simply use the `opam-health-check` command. First you need to initialize it like so:
```
$ opam-health-check init --from-local-workdir "$workdir"
```

Now you can send any command to the server using the `opam-health-check` command.
All subcommands may be listed with `opam-health-check --help`

### OCluster capability file

opam-health-check now uses OCluster for its daily use. This means you need
access to an OCluster instance with its dedicated capability file, which is
given to the server through the `--connect` option.

To set this up locally, you will need to get run the OCluster scheduler and one or more workers. The
sequence of steps is:

1. Run the OCluster scheduler probably with the public address `tcp:127.0.0.1:9000`.
2. Use the OCluster admin command to generate the submission capability for
   opam-health-check, it will most likely be something like
   ```
   $ ocluster-admin add-client --connect ./capnp-secrets/admin.cap opam-health-check > ~/ocluster.cap`.
   ```
3. Add a new worker to the pool you are using.
4. Run `opam-health-serve`.
5. Initialise `opam-health-check` as described above, add some opam switches and
   then run the checks.

### How to use opam-health-check remotely:

As with local opam-health-check you need to have a server started somewhere and accessible.
Don't forget to open the admin and http ports. Default ports are respectively 6666 and 8080.
You can change them by modifying the yaml config file at the root of the work directory and
restarting the server.

During the first run the server creates an admin user and its key.
To connect to the server remotely just you first need to retreive the `admin.key` file located
in `<workdir>/keys/admin.key` and do `opam-health-check init`.
From there, answer all the questions (hostname, admin-port (default: 6666), username (admin)
and the path to the user key you just retreived).
You now have your client tool configured with an admin user!

To add new users, just use the `opam-health-check add-user <username>` command as the admin and
give the key to your new user. She now just need to do the same procedure but with her username.

Side note: every user have the same rights and can add new users.

Enjoy.

## Troubleshooting

**My `config.yaml` file is getting reset when I edit it!**

You should make sure no instance of `opam-health-serve` is running before editing an instance configuration file.

**I started `opam-health-serve`, ran `opam-health-check run`, and nothing seems to be happening.**

Overall this takes a while. You can run `opam-health-check log` to follow the progress. Once it's done, you can visit `http://localhost:port` (where `port` is set in your `config.yaml`) to visualize the results.

**Can I use opam-health-check to build packages on a custom compiler switch?**

Sure, to do that, you need to fork [opam-repository](https://github.com/ocaml/opam-repository/), add your compiler switch to it, and point to your forked repository in the `extra-repositories` field of the `config.yaml` file. E.g.:

```
name: default
port: 8080
# [...]
default-repository: ocaml/opam-repository
extra-repositories:
- alpha:
    github: kit-ty-kate/opam-alpha-repository
    for-switches:
    - 5.0+more_volatile
- more-volatile-switch:
    github: OlivierNicole/opam-repository#more_volatile_switch
    for-switches:
    - 5.0+more_volatile
with-test: false
with-lower-bound: false
list-command: opam list --available --installable --short --all-versions
# [...]
ocaml-switches:
- "4.14": 4.14.0
- "5.0": 5.0.0
- "5.0+more_volatile": ocaml-variants.5.0.0+more_volatile
slack-webhooks: []
```
