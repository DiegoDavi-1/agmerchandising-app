# Guia de Teste - Integração Flutter com Sistema de Campos Dinâmicos

## ✅ Checklist de Validação Completa

### 1. Configuração no Admin Dashboard

**Acesse:** https://agmerchandising.online/admin/

#### Teste A: Criar Marca com Template
1. Na seção MARCAS, clique em "Nova Marca"
2. Preencha:
   - Nome: `Teste Auditoria`
   - Descrição: `Marca para teste de campos dinâmicos`
3. No dropdown "Template", selecione: `📋 Auditoria`
4. Clique em "Criar"
5. ✅ Verificar: Marca aparece na tabela

#### Teste B: Visualizar Campos Aplicados
1. Na linha da marca criada, clique em **Configurar**
2. ✅ Verificar no modal:
   - ☑️ compliance_check (Checkbox) - obrigatório
   - 📷 compliance_photo (Photo) - 5 fotos máx
   - 📝 observations (Textarea)
   - 📅 audit_date (Date) - obrigatório

#### Teste C: Adicionar Campo Personalizado
1. No modal ainda aberto, preencha:
   - Tipo: `Text`
   - Label: `Auditor Responsável`
   - Nome: `auditor_name`
   - ✅ Marcar: **Obrigatório**
2. Clique em "Adicionar Campo"
3. ✅ Verificar: Campo aparece na lista

### 2. Teste no App Flutter

**Dispositivo:** Android/iOS ou Emulador

#### Teste D: Login e Seleção de Marca
1. Abra o app AG Merchandising
2. Faça login com credenciais válidas
3. Na tela de marcas, localize: `Teste Auditoria`
4. Toque na marca
5. ✅ Verificar: Navega para DynamicBrandCollectionPage

#### Teste E: Carregamento de Campos
1. ✅ Verificar loading: "Carregando campos da marca..."
2. ✅ Verificar header: "5 campos configurados"
3. ✅ Verificar lista renderizada:
   - compliance_check (Checkbox com asterisco vermelho)
   - compliance_photo (Botão de câmera)
   - observations (Textarea grande)
   - audit_date (Seletor de data com asterisco)
   - auditor_name (Campo de texto com asterisco)

#### Teste F: Preenchimento de Campos

**Checkbox:**
1. Toque no checkbox "compliance_check"
2. ✅ Verificar: Fica marcado

**Photo (Múltiplas fotos):**
1. Toque em "Adicionar Foto" no campo compliance_photo
2. Permita acesso à câmera (se solicitado)
3. Tire uma foto
4. ✅ Verificar: Thumbnail aparece (80x80)
5. Tire mais 2 fotos
6. ✅ Verificar: 3 thumbnails exibidos
7. Toque no ❌ de uma foto
8. ✅ Verificar: Foto removida

**Textarea:**
1. Toque no campo observations
2. Digite: `Produto bem posicionado. Etiquetas de preço visíveis.`
3. ✅ Verificar: Texto aparece com quebras de linha

**Date:**
1. Toque no campo audit_date
2. Selecione: Hoje
3. ✅ Verificar: Data formatada em dd/MM/yyyy

**Text:**
1. Toque no campo auditor_name
2. Digite: `João Silva`
3. ✅ Verificar: Texto aparece

#### Teste G: Validação de Campos Obrigatórios
1. Deixe auditor_name vazio
2. Desmarque compliance_check
3. Toque em "Salvar Coleta"
4. ✅ Verificar: Snackbar vermelho: "Campo obrigatório não preenchido: compliance_check"

#### Teste H: Salvamento com Sucesso
1. Marque compliance_check
2. Preencha todos os campos obrigatórios
3. Toque em "Salvar Coleta"
4. ✅ Verificar:
   - Loading no botão
   - Snackbar verde: "✅ Coleta salva com sucesso!"
   - Volta para tela de marcas
   - Snackbar: "Coleta registrada!"

### 3. Validação no Backend

**Acesse:** Terminal SSH ou PM2 logs

#### Teste I: Verificar Log de Auditoria
```bash
# Via PM2
pm2 logs ag-merchandising --lines 50 | grep "AUDIT"

# Ou via MySQL
mysql -u root -p agmerchandising
SELECT * FROM audit_logs ORDER BY timestamp DESC LIMIT 5;
```

✅ Verificar registro:
- action: `collection_create`
- brandId: ID da marca de teste
- userId: Seu ID de usuário

#### Teste J: Verificar Dados Salvos
```sql
-- Buscar coletas recentes
SELECT * FROM collections 
WHERE brand_id = (SELECT id FROM brands WHERE name = 'Teste Auditoria')
ORDER BY created_at DESC LIMIT 1;
```

✅ Verificar:
- `data` (JSON) contém:
  ```json
  {
    "compliance_check": true,
    "compliance_photo": ["path/to/photo1.jpg", "path/to/photo2.jpg"],
    "observations": "Produto bem posicionado...",
    "audit_date": "2024-01-15",
    "auditor_name": "João Silva"
  }
  ```
- `latitude` e `longitude` preenchidos
- `location_address` presente

### 4. Teste de Marca Sem Campos

#### Teste K: Marca Sem Configuração
1. No admin, crie marca: `Teste Vazio`
2. Não selecione template
3. Não adicione campos manualmente
4. No app, selecione `Teste Vazio`
5. ✅ Verificar mensagem:
   - Ícone laranja ⚠️
   - "Esta marca não tem campos configurados."
   - "Configure campos no Admin Dashboard primeiro."

### 5. Teste de Erros e Edge Cases

#### Teste L: Modo Offline
1. Desative Wi-Fi e dados móveis
2. Tente selecionar uma marca
3. ✅ Verificar: Erro de rede exibido

#### Teste M: Token Expirado
1. Espere 1 hora sem usar o app
2. Selecione uma marca
3. ✅ Verificar: Token renovado automaticamente (ou redirect para login)

#### Teste N: Limite de Fotos
1. Adicione fotos até maxPhotos (5 fotos)
2. ✅ Verificar: Botão "Adicionar Foto" desaparece

### 6. Teste de Performance

#### Teste O: Marca com Muitos Campos
1. No admin, crie marca: `Teste Performance`
2. Adicione 20 campos de tipos variados
3. No app, abra essa marca
4. ✅ Verificar:
   - Carregamento rápido (< 2s)
   - Scroll suave
   - Sem travamentos

### 7. Checklist Final de Validação

- [ ] Admin: Criar marca com template ✅
- [ ] Admin: Visualizar campos aplicados ✅
- [ ] Admin: Adicionar campo customizado ✅
- [ ] App: Login e navegação ✅
- [ ] App: Carregamento de campos dinâmicos ✅
- [ ] App: Checkbox funcional ✅
- [ ] App: Photo múltiplas fotos ✅
- [ ] App: Photo deletar foto ✅
- [ ] App: Textarea multi-linha ✅
- [ ] App: Date picker ✅
- [ ] App: Text campo simples ✅
- [ ] App: Validação de campos obrigatórios ✅
- [ ] App: Salvamento com sucesso ✅
- [ ] Backend: Audit log registrado ✅
- [ ] Backend: Dados salvos corretamente ✅
- [ ] App: Marca sem campos exibe aviso ✅
- [ ] App: Modo offline tratado ✅
- [ ] App: Limite de fotos respeitado ✅

---

## 🐛 Troubleshooting

### Problema: Campos não carregam
**Solução:**
```bash
# Verificar se marca tem campos
mysql -u root -p agmerchandising
SELECT * FROM brand_fields WHERE brand_id = <ID_DA_MARCA>;
```

### Problema: Erro 401 ao salvar
**Solução:**
- Verificar se token não expirou
- Conferir _getHeaders() em api_service.dart
- Testar endpoint manualmente:
```bash
curl -H "Authorization: Bearer $TOKEN" \
  https://agmerchandising.online/api/collections \
  -X POST -d '{"brandId": 1, "data": {}}'
```

### Problema: Fotos não salvam
**Solução:**
- Verificar permissões de câmera no AndroidManifest.xml
- Conferir se ImagePicker está configurado
- Validar upload_path no backend

### Problema: Location null
**Solução:**
- Verificar permissões de localização
- Testar LocationService.getCurrentPosition()
- Habilitar GPS no dispositivo

---

## 📊 Métricas de Sucesso

| Métrica | Valor Esperado | Status |
|---------|----------------|--------|
| Tempo de carregamento | < 2s | ⏱️ |
| Taxa de erro | < 1% | 📉 |
| Campos renderizados | 100% | ✅ |
| Validações funcionando | 100% | ✅ |
| Salvamento bem-sucedido | > 95% | 💾 |

---

## 🎯 Próximos Passos

1. [ ] Implementar cache local de campos (SharedPreferences)
2. [ ] Adicionar modo offline (salvar localmente e sincronizar depois)
3. [ ] Implementar upload de fotos para servidor
4. [ ] Adicionar histórico de coletas por marca
5. [ ] Criar relatório PDF com campos dinâmicos
6. [ ] Adicionar busca/filtro de marcas
7. [ ] Implementar notificações de coletas pendentes
