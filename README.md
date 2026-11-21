# Red Dragon M913 para Mac

App nativo para macOS que configura o mouse **Redragon M913 Impact Elite** (sem fio e com cabo) e mostra a bateria dele no Mac. O programa oficial da Redragon só existe para Windows.

*English below.*

> App **não oficial**, sem nenhum vínculo com a Redragon. Nome e logo pertencem aos donos da marca.

## O que faz

- **Bateria na barra do topo**, com o logo da Redragon, a porcentagem e um raio quando está carregando.
- **Bateria no widget de Baterias do macOS**, ao lado do Magic Mouse e do teclado.
- **Avisos**: bateria baixa (20%), começou a carregar e carregou.
- **Ícone só com o mouse ligado**: desligou o mouse, o ícone some. Abrir o app de novo pelo Finder mostra o ícone mesmo assim.
- **16 botões** (12 laterais, esquerdo, direito, rodinha e o botão de tiro). Cada um pode virar:
  - atalho de teclado, inclusive com ⌘ ⌥ ⌃ ⇧;
  - mídia (tocar, volume, faixa);
  - navegador (voltar, avançar, atualizar);
  - DPI (aumentar, diminuir, ciclo, mira);
  - clique duplo ou triplo;
  - tiro rápido.
- **DPI**: 5 níveis de 100 a 16000 e quantos ficam em uso.
- **Luz do logo**: desligada, fixa (cor e brilho), respiração ou arco-íris.
- **Taxa de resposta**: 125, 250, 500 ou 1000 Hz.

Tudo é gravado na memória do próprio mouse, então vale em qualquer computador, mesmo sem o app aberto. Antes de mudar qualquer coisa, o app guarda uma cópia da configuração em `~/Library/Application Support/M913/`.

## Instalar

1. Baixe o `Red-Dragon-M913.zip` em [Releases](../../releases) e descompacte.
2. Arraste **Red Dragon M913** para a pasta **Aplicativos**.
3. Abra com o botão direito > **Abrir**. Como o app não é assinado por um desenvolvedor da Apple, o macOS pergunta na primeira vez.

   Se o macOS não deixar abrir, rode no Terminal:
   ```bash
   xattr -dr com.apple.quarantine "/Applications/Red Dragon M913.app"
   ```
4. Libere em **Ajustes do Sistema > Privacidade e Segurança > Monitoramento de Entrada**. O receptor do mouse se apresenta como teclado, por isso o macOS pede essa permissão. O app conecta sozinho depois disso.
5. No menu do ícone, marque **Abrir ao ligar o Mac**.

Requer macOS 14 ou mais novo. Funciona em Mac com Apple Silicon e com Intel.

## Compilar

Precisa das ferramentas de linha de comando do Xcode.

```bash
./empacotar.sh
```

O script compila e instala em `/Applications`.

## Compatibilidade

Testado com o receptor `25a7:fa07` (sem fio) e o cabo `25a7:fa08`. A revisão mais nova do M913, com chip Compx (`3554:f55d`), usa outro protocolo e **não** é suportada.

## Créditos e licença

O protocolo vem da engenharia reversa feita nestes projetos:

- [m913-ctl](https://github.com/Qehbr/m913-ctl), ferramenta para Linux;
- [Redragon M913 Web Configurator](https://github.com/Olek97/Redragon_M913_Web_Configurator);
- [mouse_m908](https://github.com/dokutan/mouse_m908).

O logo vem do [Simple Icons](https://simpleicons.org).

Licença **GPL-3.0**, a mesma dos projetos de origem.

---

## English

Native macOS menu bar app for the **Redragon M913 Impact Elite** wireless mouse. Redragon's official software is Windows-only. This app is unofficial and not affiliated with Redragon.

- **Battery level in the menu bar** with a charging indicator.
- **Battery in the macOS Batteries widget.**
- **Notifications** for low battery and charging.
- **Remapping of all 16 buttons**: keyboard shortcuts, media, browser, DPI, double click and rapid fire.
- **5 DPI stages.**
- **Logo LED effects.**
- **Polling rate** of 125 to 1000 Hz.

Everything is saved to the mouse's onboard memory.

**Install:**
1. Download the zip from Releases and move the app to Applications.
2. Right-click the app and choose Open.
3. Allow it in System Settings > Privacy & Security > Input Monitoring.

**Build:** run `./empacotar.sh`.

**Hardware:** supports the Areson revision (`25a7:fa07` / `25a7:fa08`). It does not support the Compx revision (`3554:f55d`).

**Credits:** the protocol comes from the projects credited above. Licensed under GPL-3.0.
