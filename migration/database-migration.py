import os
import sys
import logging
import sqlalchemy
from sqlalchemy import create_engine, inspect
from sqlalchemy.orm import sessionmaker
from sqlalchemy.exc import SQLAlchemyError
import pandas as pd
import json
import boto3

class DatabaseMigrationManager:
    def __init__(self, source_config, target_config):
        """
        Initialize database migration manager
        
        :param source_config: Source database connection configuration
        :param target_config: Target database connection configuration
        """
        self.source_engine = create_engine(source_config)
        self.target_engine = create_engine(target_config)
        
        # Configure logging
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
        )
        self.logger = logging.getLogger(__name__)
        
        # AWS Secrets Manager for credentials
        self.secrets_manager = boto3.client('secretsmanager')

    def get_schema_metadata(self, engine):
        """
        Retrieve database schema metadata
        
        :param engine: SQLAlchemy database engine
        :return: Dictionary of schema metadata
        """
        inspector = inspect(engine)
        schema_metadata = {
            'tables': inspector.get_table_names(),
            'views': inspector.get_view_names(),
            'foreign_keys': {}
        }
        
        for table in schema_metadata['tables']:
            schema_metadata['foreign_keys'][table] = inspector.get_foreign_keys(table)
        
        return schema_metadata

    def validate_schema_compatibility(self, source_schema, target_schema):
        """
        Validate schema compatibility between source and target
        
        :param source_schema: Source database schema metadata
        :param target_schema: Target database schema metadata
        :return: Boolean indicating compatibility
        """
        compatibility_checks = {
            'table_count_match': len(source_schema['tables']) == len(target_schema['tables']),
            'view_count_match': len(source_schema['views']) == len(target_schema['views']),
            'foreign_key_compatibility': True
        }
        
        # Detailed foreign key compatibility check
        for table, foreign_keys in source_schema['foreign_keys'].items():
            if table in target_schema['foreign_keys']:
                if len(foreign_keys) != len(target_schema['foreign_keys'][table]):
                    compatibility_checks['foreign_key_compatibility'] = False
                    break
        
        return all(compatibility_checks.values())

    def incremental_data_migration(self, table, last_migration_timestamp=None):
        """
        Perform incremental data migration for a specific table
        
        :param table: Table name to migrate
        :param last_migration_timestamp: Timestamp of last migration
        :return: Number of rows migrated
        """
        try:
            # Create source and target sessions
            SourceSession = sessionmaker(bind=self.source_engine)
            TargetSession = sessionmaker(bind=self.target_engine)
            
            source_session = SourceSession()
            target_session = TargetSession()
            
            # Build query with incremental filter
            query = source_session.query(table)
            if last_migration_timestamp:
                query = query.filter(table.updated_at > last_migration_timestamp)
            
            # Migrate data in batches
            batch_size = 1000
            migrated_rows = 0
            
            for batch in pd.read_sql(query.statement, source_session.bind, chunksize=batch_size):
                target_session.bulk_insert_mappings(table, batch.to_dict('records'))
                target_session.commit()
                migrated_rows += len(batch)
            
            return migrated_rows
        
        except SQLAlchemyError as e:
            self.logger.error(f"Migration error for table {table}: {e}")
            target_session.rollback()
            return 0
        finally:
            source_session.close()
            target_session.close()

    def full_database_migration(self):
        """
        Perform full database migration with validation and logging
        """
        migration_report = {
            'timestamp': datetime.now().isoformat(),
            'source_schema': self.get_schema_metadata(self.source_engine),
            'target_schema': self.get_schema_metadata(self.target_engine),
            'migration_status': {},
            'errors': []
        }
        
        # Validate schema compatibility
        if not self.validate_schema_compatibility(
            migration_report['source_schema'], 
            migration_report['target_schema']
        ):
            self.logger.error("Schema incompatibility detected")
            return migration_report
        
        # Migrate tables
        for table in migration_report['source_schema']['tables']:
            try:
                rows_migrated = self.incremental_data_migration(table)
                migration_report['migration_status'][table] = rows_migrated
            except Exception as e:
                migration_report['errors'].append({
                    'table': table,
                    'error': str(e)
                })
        
        return migration_report

    def rollback_migration(self, migration_report):
        """
        Rollback migration based on migration report
        
        :param migration_report: Migration report from full_database_migration
        """
        try:
            target_session = sessionmaker(bind=self.target_engine)()
            
            # Rollback tables in reverse order
            for table in reversed(migration_report['source_schema']['tables']):
                target_session.execute(f"DELETE FROM {table}")
            
            target_session.commit()
            self.logger.info("Migration rollback completed successfully")
        
        except SQLAlchemyError as e:
            self.logger.error(f"Rollback error: {e}")
            target_session.rollback()

def main():
    # Retrieve database credentials from AWS Secrets Manager
    secrets_manager = boto3.client('secretsmanager')
    source_credentials = json.loads(
        secrets_manager.get_secret_value(SecretId='source-db-credentials')['SecretString']
    )
    target_credentials = json.loads(
        secrets_manager.get_secret_value(SecretId='target-db-credentials')['SecretString']
    )

    # Construct database connection strings
    source_config = f"oracle+cx_Oracle://{source_credentials['username']}:{source_credentials['password']}@{source_credentials['host']}:{source_credentials['port']}/{source_credentials['database']}"
    target_config = f"oracle+cx_Oracle://{target_credentials['username']}:{target_credentials['password']}@{target_credentials['host']}:{target_credentials['port']}/{target_credentials['database']}"

    # Initialize migration manager
    migration_manager = DatabaseMigrationManager(source_config, target_config)
    
    # Perform full database migration
    migration_report = migration_manager.full_database_migration()
    
    # Save migration report
    with open('migration_report.json', 'w') as f:
        json.dump(migration_report, f, indent=2)
    
    # Optional: Rollback if migration fails
    if migration_report.get('errors'):
        migration_manager.rollback_migration(migration_report)

if __name__ == '__main__':
    main()