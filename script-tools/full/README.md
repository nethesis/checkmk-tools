# script-tools/full - Struttura parlante

Questa cartella è organizzata per **uso funzionale**.

## Sottocartelle

- `backup_restore/`  
  Backup, restore, compressione backup, retention, rclone space.

- `deploy/`  
  Deploy script/check, smart deploy, deploy monitoraggio.

- `installation/`  
  Installazione agent, FRPC, componenti e setup correlati.

- `upgrade_maintenance/`  
  Upgrade, pre-upgrade, rocksolid startup check, ottimizzazioni e maintenance.

- `sync_update/`  
  Auto-git-sync, update script, update crontab, sync da repo.

- `monitoring_diagnostics/`  
  Tuning, diagnostica, debug monitor, distributed monitoring setup.

- `network_scan/`  
  Script di scansione nmap.

- `wrappers_templates/`  
  Template e wrapper di esempio.

- `misc/`  
  Script non ancora riclassificati in un dominio più specifico.

## Regola operativa

- Gli script stanno nelle rispettive sottocartelle categoria.
- In root `script-tools/full` non devono esserci script `.sh`/`.py`.
- Niente wrapper legacy: i path da usare sono quelli delle cartelle categoria.
