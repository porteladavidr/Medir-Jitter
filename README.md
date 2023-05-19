# Medir-Jitter
Projeto em powershell para medir jitter de conexão, focado em cenários de ligações voip

Uma observação:
Como trabalho com sistemas VOIP geralmente utilizo para verificar o jitter com a operadora de telefonia neste caso o trecho abaixo, remete a um retorno
Que esperamos como bom entre o servidor de discagem e a operadora.
Por padrão o Jitter tolerável é de 30ms, porém em algumas situações pode ser até 50ms.
Já na perda de pacotes acima de 1% já pode-se considerar falhas.

Deixei o Jitter em 5 somente para validar o script.

 if($jitter -ge 5 -or $PacotePerdido -ge 1){
        $Resultado | Add-Member -MemberType NoteProperty -Name 'Falha' -value "Há picote e/ou voz robotizada"
    }else{
        $Resultado | Add-Member -MemberType NoteProperty -Name 'Falha' -value "Sem falhas"
    }
