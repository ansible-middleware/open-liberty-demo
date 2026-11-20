# open-liberty-demo

A demo to set up a simple Open Liberty fleet and deploy a sample application with the
[`middleware_automation.open_liberty`](https://github.com/ansible-middleware/open-liberty) Ansible collection.
It takes each host in the inventory from bare Linux server to running Open Liberty with an app deployed, in a single playbook.

## What the demo does

`playbook.yml` runs these collection roles on every host in the `liberty_servers` group:

| Role            | What it does in this demo                                                                 |
|-----------------|-------------------------------------------------------------------------------------------|
| `install`       | Installs OpenJDK 21, creates the `liberty` user/group, downloads Open Liberty `24.0.0.9` (Web Profile) from Maven Central into `/opt/openliberty/wlp` |
| `server_config` | Creates `demoServer`, renders `server.xml` (`webProfile-10.0` + `mpHealth-4.0`, HTTP port `9080`, AUDIT logging) and `jvm.options` |
| `systemd`       | Creates and starts `openliberty-demoServer.service`, setting `APP_ENV` and `DEMO_NODE_NAME` as environment variables |
| `app_deploy`    | Deploys the sample `hello-liberty.war` at the `/hello` context root using a `configDropins/overrides` entry |
| `validation`    | Checks the service is active, the port is open, and `/health` returns HTTP 200            |

The `post_tasks` (`validate.yml` / `info.yml`) then check the welcome page and `/health` (`status: UP`), and print the
response from the deployed application:

```
Hello from Open Liberty, deployed by Ansible!
Server info : IBM WebSphere Liberty/24.0.0.9
Node        : liberty1.example.com
Environment : demo
Java        : Red Hat, Inc. 21.0.x
```

The sample app source is in `app/hello-liberty/` (a single JSP). The playbook packages it into `app/hello-liberty.war` on the controller, so you don't need Maven.

### Extra playbooks

* `upgrade.yml` upgrades Open Liberty in place (rolling, `serial: 1`) to `24.0.0.12` with the `version_update` role.
  It keeps a backup and blocks downgrades. Afterwards, the app's `Server info` line shows the new version.
* `port_config.yml` moves Open Liberty to a new HTTP port with the `port_config` role. It doesn't touch the app.
  The role writes a `configDropins/overrides/port_config.xml` override and keeps `httpPort` in `server.xml` in sync.
  The playbook then checks the server and app on the new port and confirms the old port is closed.
* `uninstall.yml` decommissions everything with the `uninstall` role.

Settings shared by every playbook (`openliberty_server_name`, `openliberty_http_port`) are in `group_vars/all.yml`.

## Prerequisites

* Ansible core 2.16 or later on the controller
* Target hosts running RHEL 8, 9, or 10 (or a compatible distribution), reachable as `root` over SSH

```sh
ansible-galaxy collection install -r requirements.yml
```

## Running the demo

1. Put your target hosts in `inventory`:

    ```ini
    [liberty_servers]
    liberty1.example.com
    liberty2.example.com
    ```

2. Install, configure, deploy, and validate:

    ```sh
    ansible-playbook -i inventory playbook.yml
    ```

    Run it again. Every task is idempotent, so the second run reports `changed=0`.

3. Open `http://<host>:9080/hello/` in a browser (use the port from `group_vars/all.yml`), or run:

    ```sh
    curl http://<host>:9080/hello/
    curl http://<host>:9080/health
    ```

4. (Optional) Move to port 8080. Set `openliberty_http_port: 8080` in `group_vars/all.yml`, then run:

    ```sh
    ansible-playbook -i inventory port_config.yml
    ```

    ```
    TASK [Show the planned change]
    ok: [liberty1.example.com] => { "msg": "HTTP port 9080 -> 8080" }
    ...
    TASK [Check the old HTTP port is closed]
    ok: [liberty1.example.com]
    ```

    Change the port in `group_vars/all.yml`, not with `-e` on a single run. The override file keeps the new port, so
    if `playbook.yml` and `upgrade.yml` later run with the old value, their checks look at a port that's closed.
    To also open the new port in firewalld or ufw, add `-e openliberty_firewall_port_manage=true`. The role doesn't
    close the old port's firewall rule.

5. (Optional) Upgrade, then tear down:

    ```sh
    ansible-playbook -i inventory upgrade.yml
    ansible-playbook -i inventory uninstall.yml
    ```

Useful overrides: `-e hosts_group_name=<group>`, `-e override_openliberty_version=<version>`, and
`-e override_openliberty_new_version=<version>` (for `upgrade.yml`).

## Testing with Molecule

The Molecule scenario starts two UBI 9 containers (`liberty-node-1` on port 9080, `liberty-node-2` on port 9180).
It runs `playbook.yml` against them, checks idempotence, and verifies that each node serves `/hello` and `/health`:

```sh
pip install 'molecule>=6.0.3' 'molecule-plugins[docker]>=23.5.3' ansible-core
molecule test
```

## Continuous integration

[`.github/workflows/ci.yml`](.github/workflows/ci.yml) runs on every push to `main`, on pull requests,
and daily. It lints the repo with `yamllint` and `ansible-lint`, then runs `molecule test` against the
two-node Docker scenario.

## References

* Collection: https://github.com/ansible-middleware/open-liberty
* Ansible Galaxy: https://galaxy.ansible.com/middleware_automation/open_liberty
* Open Liberty: https://openliberty.io
