#####   NOME:                   Medir Jitter.ps1
#####   VERSÃO:                 1.0
#####   DESCRIÇÃO:              Configura dependências de subida dos serviços do TactiumIP
#####   DATA DA CRIAÇÃO:        04/05/2023
#####   DATA DA MODIFICAÇÃO:    Sem modificações
#####   ESCRITO POR:            David Portela
#####   PROJETO:                https://github.com/porteladavidr/Medir-Jitter

<#
.SINOPSE
    Testa o jitter (variação da latência da rede) em relação ao computador remoto.

.DESCRIÇÃO
    O cmdlet Testar-Jitter testa a instabilidade em um ou mais computadores especificados. Em casos de ligações falhando somente na PA (Ou seja as ligações em E1
    Não apresentam falhas) é importante medir o Jitter entre a PA e o servidor

.EXEMPLO
    Testar-Jitter -GerarRelatorio $True -NomeDoRelatorio 'test_jitter.csv'
    Este exemplo executará Testar-Jitter e gerará um relatório no diretório atual dos resultados chamado 'test_jitter.csv'.

.EXEMPLO
    Testar-Jitter -Contagem '25' -Passa '10'
    Este exemplo executará Testar-Jitter executando cada teste 25 vezes e, em seguida, executando o teste inteiro 10 vezes e calculando a média dos resultados.

.PARAMETER ComputerName
    O nome do computador, ou endereço IP, do computador no qual você deseja testar o jitter.

.PARAMETER Contagem
    O número de vezes que você deseja testar a conexão com o destino.

.PARAMETER Passes
    O número de vezes que você deseja executar todo o teste e tirar a média dos resultados.

.PARAMETER GerarRelatório
    Se você deseja ou não gerar um relatório de jitter .csv dos resultados.

.PARAMETER ExportPath
    O caminho UNC para o destino de exportação do relatório.

.PARAMETER NomeDoRelatorio
    O nome do arquivo a ser usado para o relatório de jitter. o padrão é jitter_report.csv

.PARAMETER ModoRecorrente
    O Modo Recorrente criará um novo diretório em $ExportPath e separará os dados em relatórios diários individuais.
#>
Param
(
    [Parameter(
        Mandatory=$False,
        HelpMessage='Qual nome de computador você gostaria de segmentar? O padrão é Google DNS (8.8.8.8).'
    )]
    [string]$ComputerName = '8.8.8.8',

    [Parameter(
        Mandatory=$False,
        HelpMessage='Quantas vezes você gostaria de testar a conexão com o alvo? O padrão é 10.'
    )]
    [int]$Count = '20',

    [Parameter(
        Mandatory=$False,
        HelpMessage='Quantas vezes você gostaria de executar todo o teste e tirar a média dos resultados? O padrão é 3.'
    )]
    [int]$Passes = '3',

    [Parameter(
        ParameterSetName='GerarRelatorio',
        Mandatory=$False,
        HelpMessage='Defina como $True se desejar gerar um relatório .csv dos resultados. O padrão é falso.'
    )]
    [switch]$GerarRelatorio,

    [Parameter(
        ParameterSetName='GerarRelatorio',
        Mandatory=$False,
        HelpMessage='Destino UNC para relatório. O padrão é o diretório atual.'
    )]
    [string]$CaminhoDoRelatorio = (Get-Location),

    [Parameter(
        ParameterSetName='GerarRelatorio',
        Mandatory=$False,
        HelpMessage='Nome do arquivo para o relatório. O padrão é jitter_report.csv'
    )]
    [string]$NomeDoRelatorio = 'jitter_report.csv',

    [Parameter(
        ParameterSetName='GerarRelatorio',
        Mandatory=$False,
        HelpMessage='O Modo Recorrente criará um novo diretório em $ExportPath e separará os dados em relatórios diários individuais. O padrão é $Falso.'
    )]
    [switch]$ModoRecorrente
)

Begin
{
    Function Encontrar-Diferenca
    {
        Param
        (
            [int]$ReferenciaInt,
            [int]$DiferençaInt
        )

        If (($ReferenciaInt -eq $Null) -or ($DiferençaInt -eq $Null))
        {
            Write-Error -Message 'Ou $ReferenciaInt ou $DiferençaInt -eq $Null' -Category 'Encontrar-Diferenca'
            Break
        }

        If ($ReferenciaInt -gt $DiferençaInt)
        {
            $Diferenca = $ReferenciaInt - $DiferençaInt
            Write-Verbose -Message ('$Diferenca = ' + $Diferenca)
            $Diferenca
        }

        Else
        {
            $Diferenca = $DiferençaInt - $ReferenciaInt
            Write-Verbose -Message ('$Diferenca = ' + $Diferenca)
            $Diferenca
        }
    }

    Function Testar-Jitter
    {
        Param
        (
            [string]$ComputerName,
            [int]$Count
        )

        $Resultado = New-Object -TypeName System.Object
        [int]$DiferencaTotal = '0'

        Write-Verbose -Message ("Rodando 'Test-Connection -ComputerName $ComputerName -Count $Count'")
        $Test = Test-Connection -ComputerName $ComputerName -Count $Count

        Write-Verbose -Message ('$PacotePerdido = 100 - ((' + $Test.ResponseTime.Count + ' / ' + $Count + ') * 100)')
        $PacotePerdido = 100 - (($Test.ResponseTime.Count / $Count) * 100)

        Write-Verbose -Message ("Percorrendo o Tempo de resposta")
        $i = 0
        While ($i -lt ($Test.ResponseTime.Count))
        {
            Write-Verbose -Message ('Encontrando a diferença entre ' + $Test[$i].ResponseTime + ' e ' + $Test[($i+1)].ResponseTime)
            $Diferenca = Encontrar-Diferenca -ReferenciaInt $Test[$i].ResponseTime -DiferençaInt $Test[($i+1)].ResponseTime
            Write-Verbose -Message ("Adicionando a $Diferenca em " + 'DiferencaTotal ' + "(DiferencaTotal)")
            $DiferencaTotal += $Diferenca
            Write-Verbose -Message ('DiferencaTotal = ' + $DiferencaTotal)
            $i++
        }

        Write-Verbose ('Calculando Jitter (' + $DiferencaTotal + ' / ' + $Test.ResponseTime.Count + ')')
        [int]$Jitter = $DiferencaTotal / $Test.ResponseTime.Count
        Write-Verbose ('$Jitter = ' + $Jitter + ', arredondamento $Jitter')
        [int]$Jitter = [math]::Round($Jitter, [System.MidpointRounding]::AwayFromZero)
        Write-Verbose -Message ('$Jitter = ' + $Jitter)

        Write-Verbose -Message ('Adicionando jitter(ms) a $Resultado ' + "($Jitter)")
        $Resultado | Add-Member -MemberType NoteProperty -Name 'jitter(ms)' -Value $Jitter
        Write-Verbose -Message ('Adicionando perda de pacotes (%) a $Resultado ' + "($PacotePerdido)")
        $Resultado | Add-Member -MemberType NoteProperty -Name 'packetloss(%)' -Value $PacotePerdido

        Write-Verbose -Message 'Retornando resultados'
        Return $Resultado
    }

    Function Exportar-RelatorioJitter
    {
        Param
        (
            [string]$CaminhoDoRelatorio,
            [string]$NomeDoRelatorio,
            [string]$ComputerName,
            $ExportObject
        )

        If ($ModoRecorrente)
        {
            Write-Verbose -Message ('$ModoRecorrente = $True')
            $NomeDaPasta = 'Relatorio_Jitter_Recorrente'
            Write-Verbose -Message ('$NomeDaPasta = ' + $NomeDaPasta)
            $NomeDoRelatorio = ($Data + '.csv')
            Write-Verbose -Message ('$NomeDoRelatorio = ' + $NomeDoRelatorio)
            $ExportPath = ($CaminhoDoRelatorio + '\' + $NomeDaPasta + '\' + $NomeDoRelatorio)
            Write-Verbose -Message ('$ExportPath = ' + $ExportPath)
            If (!(Test-Path -Path ($CaminhoDoRelatorio + '\' + $NomeDaPasta) -ErrorAction SilentlyContinue))
            {
                Write-Verbose -Message ('Criando pasta com o nome ' + $NomeDaPasta + 'Aqui: ' + $CaminhoDoRelatorio)
                $CriarPasta = New-Item -Path $CaminhoDoRelatorio -Name $NomeDaPasta -ItemType 'Diretório' -ErrorAction SilentlyContinue
            }
            Write-Verbose -Message ('Exportando Relatório')
            $ExportCSV = Export-Csv -InputObject $ExportObject -Path $ExportPath -Append -NoTypeInformation
        }
        Else
        {
            Write-Verbose -Message ('$ModoRecorrente = $True')
            $ExportPath = ($CaminhoDoRelatorio + '\' + $NomeDoRelatorio)
            Write-Verbose -Message ('$ExportPath = ' + $ExportPath)
            Write-Verbose -Message ('Building $ExportObject')
            $ExportCSV = Export-Csv -InputObject $ExportObject -Path $ExportPath -Append -NoTypeInformation
            Write-Verbose -Message ('Exporting report')
        }
    }
}

Process
{
    [int]$TotalJitter = '0'
    [int]$TotalPacketLoss = '0'
    [int]$i = '0'
    Write-Verbose -Message ('$Passes = ' + $Passes)

    While ($i -lt $Passes)
    {
        Write-Verbose -Message ('Iniciando passses # ' + $i)
        Write-Verbose -Message ('Testando o jitter contra ' + $ComputerName + ' $Count = ' + $Count)
        $JitterTest = Testar-Jitter -ComputerName $ComputerName -Count $Count

        Write-Verbose -Message ('Adicionando ' + $JitterTest.'jitter(ms)' + ' to $TotalJitter ' + "($TotalJitter)")
        $TotalJitter += $JitterTest.'jitter(ms)'
        Write-Verbose -Message ('Adicionando ' + $JitterTest.'packetloss(%)' + ' to $TotalPacketLoss ' + "($TotalPacketLoss)")
        $TotalPacketLoss += $JitterTest.'packetloss(%)'

        $i++
    }

    Write-Verbose -Message ('Calculando o Jitter final (' + $TotalJitter + ' / ' + $Passes + ')')
    $Jitter = ($TotalJitter / $Passes)
    Write-Verbose -Message ('Quando o Jitter final = ' + $Jitter + ', arredondar jitter')
    $Jitter = [math]::Round($Jitter, [System.MidpointRounding]::AwayFromZero)
    Write-Verbose -Message ('Jitter final = ' + $Jitter)

    Write-Verbose -Message ('Calculando os pacotes perdidos final (' + $TotalPacketLoss + ' / ' + $Passes + ')')
    $PacotePerdido = ($TotalPacketLoss / $Passes)
    Write-Verbose -Message ('Pacotes perdidos = ' + $PacotePerdido)

    Write-Verbose -Message ('Construindo $Resultado')
    $Resultado = New-Object System.Object
    $Data = Get-Date -Format dd-MM-yyyy
    Write-Verbose -Message ('$Data = ' + $Data)
    $Tempo = Get-Date -Format 'hh:mm:ss tt'
    Write-Verbose -Message ('$Tempo = ' + $Tempo)

    If (!($ModoRecorrente))
    {
        $Resultado | Add-Member -MemberType NoteProperty -Name 'Date' -Value $Data
    }

    $Resultado | Add-Member -MemberType NoteProperty -Name 'Tempo' -Value $Tempo
    $Resultado | Add-Member -MemberType NoteProperty -Name 'Alvo' -Value $ComputerName
    $Resultado | Add-Member -MemberType NoteProperty -Name 'Jitter(ms)' -Value $Jitter
    $Resultado | Add-Member -MemberType NoteProperty -Name 'Pacotes Perdidos(%)' -Value $PacotePerdido

    if($jitter -ge 5 -or $PacotePerdido -ge 1){
        $Resultado | Add-Member -MemberType NoteProperty -Name 'Falha' -value "Há picote e/ou voz robotizada"
    }else{
        $Resultado | Add-Member -MemberType NoteProperty -Name 'Falha' -value "Sem falhas"
    }

    If ($GerarRelatorio)
    {
        Write-Verbose -Message ('Gerando relatório')
        $ExportReport = Exportar-RelatorioJitter -CaminhoDoRelatorio $CaminhoDoRelatorio -NomeDoRelatorio $NomeDoRelatorio -ComputerName $ComputerName -ExportObject $Resultado
    }
    Else
    {
        Write-Verbose -Message ('Imprimindo relatório')
        $Resultado
    }
}