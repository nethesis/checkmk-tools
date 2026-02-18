# Conversion Status - script-tools/full
> **Categoria:** Operativo

Data report: 2026-02-18

## Stato attuale

- Cartella analizzata: `script-tools/full`
- Bash (`.sh`) senza equivalente Python: **0**
- Copertura conversione Bash → Python: **100%**

## Metodo di verifica

Per confronto automatico è stata usata normalizzazione nomi:

- `-` e `_` trattati come equivalenti
- confronto per basename (`file.sh` ↔ `file.py`)

Questo evita falsi negativi su naming misto (kebab_case/snake_case).

## Decisione adottata in questa fase

Per gli script complessi o ad alto rischio operativo sono stati creati entrypoint Python che delegano allo `.sh` canonico, così da ottenere:

- interfaccia Python uniforme
- comportamento runtime invariato
- riduzione regressioni durante migrazione

## Cosa significa operativamente

- Se cerchi uno script in `script-tools/full`, ora esiste la controparte `.py`.
- Per uso immediato puoi avviare il `.py`.
- Dove presente delega interna, il `.py` inoltra args e ambiente allo `.sh` corrispondente.

## Prossimo passo consigliato (opzionale)

Se vuoi massima manutenibilità futura, puoi pianificare una fase 2:

1. identificare i wrapper Python che delegano a Bash
2. prioritizzare i più usati in produzione
3. convertire gradualmente la logica da Bash a Python nativo
