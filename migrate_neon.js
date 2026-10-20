const { Client } = require('pg');
const fs = require('fs');
const path = require('path');

const connectionString = "postgresql://neondb_owner:npg_sWtnfINB3e1J@ep-lucky-truth-b5tk44nx-pooler.c-7.us-east-2.aws.neon.tech/neondb?sslmode=require";

async function runMigration() {
  const client = new Client({
    connectionString: connectionString,
    ssl: { rejectUnauthorized: false }
  });

  try {
    console.log('Connecting to Neon PostgreSQL database...');
    await client.connect();
    console.log('Connected successfully! Reading schema.sql...');

    const schemaSql = fs.readFileSync(path.join(__dirname, 'schema.sql'), 'utf-8');
    
    console.log('Executing schema migration and table creation...');
    await client.query(schemaSql);
    console.log('Schema migration executed successfully!');

    const res = await client.query(`
      SELECT table_name 
      FROM information_schema.tables 
      WHERE table_schema = 'public' 
      ORDER BY table_name;
    `);
    
    console.log('\nCreated Tables in Neon Database:');
    res.rows.forEach(r => console.log(' - ' + r.table_name));

    const userRes = await client.query(`SELECT email, full_name, role FROM users;`);
    console.log('\nSuper Admin User Check:');
    userRes.rows.forEach(u => console.log(` - ${u.full_name} (${u.email}) [Role: ${u.role}]`));

  } catch (err) {
    console.error('Error running migration:', err);
  } finally {
    await client.end();
  }
}

runMigration();
