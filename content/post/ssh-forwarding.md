---
title: "The Problem with SSH Agent Forwarding"
date: 2019-04-12T14:00:00+03:00
tags: ["security"]
---

After hacking the [matrix.org](https://matrix.org) website today, the
hacker opened a series of GitHub issues mentioning the flaws he
discovered.  In [one of those issues][issue], he mentions that
"complete compromise could have been avoided if developers were
prohibited from using [SSH agent forwarding]".

Here's what `man ssh_config` has to say about `ForwardAgent`:

> Agent forwarding should be enabled with caution.  Users with the
> ability to bypass file permissions on the remote host (for the
> agent's Unix-domain socket) can access the local agent through the
> forwarded connection.  An attacker cannot obtain key material from
> the agent, however they can perform operations on the keys that
> enable them to authenticate using the identities loaded into the
> agent.

Put simply: if your jump box is compromised and you use SSH agent
forwarding to connect to another machine through it, then you risk
also compromising the target machine!

Instead, you should use either `ProxyCommand` or `ProxyJump` (added in
OpenSSH 7.3).  That way, ssh will forward the TCP connection to the
target host via the jump box, meaning that the actual connection
happens on your workstation and if someone on the jump box tries to
MITM your connection, then you will be warned by the SSH command.

Here's what a config file that uses `ProxyCommand` might look like:

```ssh-config
Host bastion
  Hostname bastion.example.com

Host target
  Hostname target.example.internal
  Port 2222
  ProxyCommand ssh -W %h:%p bastion
```

And here's the equivalent config using `ProxyJump`:

```ssh-config
Host bastion
  Hostname bastion.example.com

Host target
  Hostname target.example.internal
  Port 2222
  ProxyJump bastion
```

Of course, you can also specify either option via the command line:

```bash
ssh -o 'ProxyJump=bastion.example.com' target.example.internal -p 2222
```


[issue]: https://github.com/matrix-org/matrix.org/issues/357
