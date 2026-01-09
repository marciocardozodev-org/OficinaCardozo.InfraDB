Rollback de automação de migrations/scripts SQL

- O recurso null_resource.run_migrations foi removido do main.tf.
- O script wait-for-db-and-migrate.sh não é mais utilizado pelo Terraform.
- Recomenda-se excluir o arquivo wait-for-db-and-migrate.sh, ou movê-lo para uma pasta de scripts legacy, caso queira manter para referência.
- O deploy do banco agora cria apenas o recurso RDS, sem rodar scripts SQL ou migrations automáticas.
- Para inicializar a estrutura do banco, utilize o script SQL gerado pelo EF Core manualmente, a partir de uma máquina com acesso à VPC do RDS.
- Atualize a documentação e o pipeline conforme necessário.

Se precisar restaurar a automação, consulte o histórico do main.tf e do script.