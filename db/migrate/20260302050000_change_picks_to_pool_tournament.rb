 class ChangePicksToPoolTournament < ActiveRecord::Migration[8.1]
   def up
     add_reference :picks, :pool_tournament, foreign_key: true

     # Remove picks whose tournaments are not attached to any pool_tournament
     execute <<~SQL.squish
       DELETE FROM picks
       WHERE id IN (
         SELECT picks.id
         FROM picks
         LEFT JOIN pool_tournaments
           ON pool_tournaments.tournament_id = picks.tournament_id
         WHERE pool_tournaments.id IS NULL
       )
     SQL

     # For remaining picks, assign the first matching pool_tournament by tournament_id
     execute <<~SQL.squish
       UPDATE picks
       SET pool_tournament_id = sub.pt_id
       FROM (
         SELECT DISTINCT ON (picks.id)
           picks.id AS pick_id,
           pool_tournaments.id AS pt_id
         FROM picks
         JOIN pool_tournaments
           ON pool_tournaments.tournament_id = picks.tournament_id
         ORDER BY picks.id, pool_tournaments.id
       ) AS sub
       WHERE picks.id = sub.pick_id
     SQL

     change_column_null :picks, :pool_tournament_id, false

     remove_index :picks, [ :user_id, :tournament_id ]
     remove_reference :picks, :tournament, foreign_key: true

     add_index :picks, [ :user_id, :pool_tournament_id ], unique: true
   end

   def down
     add_reference :picks, :tournament, null: true, foreign_key: true

     execute <<~SQL.squish
       UPDATE picks
       SET tournament_id = pt.tournament_id
       FROM pool_tournaments AS pt
       WHERE picks.pool_tournament_id = pt.id
     SQL

     change_column_null :picks, :tournament_id, false

     remove_index :picks, [ :user_id, :pool_tournament_id ]
     remove_reference :picks, :pool_tournament, foreign_key: true

     add_index :picks, [ :user_id, :tournament_id ], unique: true
   end
 end
