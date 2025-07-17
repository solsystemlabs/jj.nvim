# New Command Workflow

```mermaid
flowchart TD
    A[User Action] --> B{Action Type}
    
    B -->|Press n on commit| C[New Child Change]
    B -->|Press N on commit| D[New Menu Options]
    B -->|leader+a action menu| E[Action Menu]
    
    %% New Child Change (simple)
    C --> F[Get commit under cursor]
    F --> G{Valid Commit?}
    G -->|No| H[Show error - no commit selected]
    G -->|Yes| I[new_child]
    
    %% New Menu Options
    D --> J[Show new options menu]
    J --> K{Select Option}
    
    K -->|c| L[New child change]
    K -->|a| M[New after change sibling]
    K -->|b| N[New before change insert]
    K -->|m| O[New merge change]
    K -->|s| P[New simple change]
    
    %% New Child Change
    L --> Q[Enter target selection mode]
    Q --> R[Select parent commit]
    R --> S[new_child parent_commit]
    
    %% New After Change
    M --> T[Enter target selection mode]
    T --> U[Select reference commit]
    U --> V[new_after reference_commit]
    
    %% New Before Change
    N --> W[Enter target selection mode]
    W --> X[Select reference commit]
    X --> Y[new_before reference_commit]
    
    %% New Merge Change
    O --> Z[Enter multi-select mode]
    Z --> AA[Select multiple parents]
    AA --> BB[new_with_change_ids parent_list]
    
    %% New Simple Change
    P --> CC[new_simple]
    
    %% Action Menu Flow
    E --> DD{Menu Selection}
    DD -->|Single Selection| EE[New child change n]
    EE --> F
    
    %% Core New Functions
    I --> FF[Validate parent commit]
    S --> FF
    V --> GG[Validate reference commit]
    Y --> GG
    BB --> HH[Validate parent commits]
    CC --> II[No validation needed]
    
    FF --> JJ[Build jj new command]
    GG --> JJ
    HH --> JJ
    II --> JJ
    
    JJ --> KK{Command Type}
    KK -->|Child| LL[jj new parent_change_id]
    KK -->|After| MM[jj new --after reference_change_id]
    KK -->|Before| NN[jj new --before reference_change_id]
    KK -->|Merge| OO[jj new parent1_change_id parent2_change_id ...]
    KK -->|Simple| PP[jj new]
    
    %% Optional Description
    LL --> QQ[Prompt for description]
    MM --> QQ
    NN --> QQ
    OO --> QQ
    PP --> QQ
    
    QQ --> RR{Description Provided?}
    RR -->|Yes| SS[Add --message flag]
    RR -->|No| TT[Use default description]
    
    SS --> UU[Build final command]
    TT --> UU
    
    %% Common Execution Path
    UU --> VV[commands.execute_with_immutable_prompt]
    VV --> WW[Execute jj command]
    WW --> XX{Success?}
    
    XX -->|Yes| YY[Extract new change_id]
    XX -->|No| ZZ[Show error message]
    
    %% Success Path
    YY --> AAA[Show success notification]
    AAA --> BBB[Return new change_id]
    BBB --> CCC[Refresh log display]
    CCC --> DDD[Update commit graph]
    DDD --> EEE[Highlight new commit]
    
    %% Error Handling
    ZZ --> FFF[Return to previous state]
    H --> FFF
    
    %% Validation Details
    FF --> GGG{Root Commit?}
    GGG -->|Yes| HHH[Allow - can create child of root]
    GGG -->|No| HHH
    HHH --> JJ
    
    GG --> III{Valid Reference?}
    III -->|No| JJJ[Show error - invalid reference]
    III -->|Yes| JJ
    JJJ --> FFF
    
    HH --> KKK{All Parents Valid?}
    KKK -->|No| LLL[Show error - invalid parents]
    KKK -->|Yes| JJ
    LLL --> FFF
    
    %% Styling
    classDef userAction fill:#e1f5fe
    classDef menuAction fill:#f3e5f5
    classDef validation fill:#fff3e0
    classDef execution fill:#e8f5e8
    classDef command fill:#fff3e0
    classDef success fill:#e8f5e8
    classDef error fill:#ffebee
    
    class A,B,C,D,E userAction
    class J,K,Q,R,T,U,W,X,Z,AA,DD,EE menuAction
    class F,G,FF,GG,HH,II,GGG,HHH,III,KKK validation
    class I,S,V,Y,BB,CC,JJ,UU,VV,WW execution
    class LL,MM,NN,OO,PP,QQ,SS,TT command
    class YY,AAA,BBB,CCC,DDD,EEE success
    class ZZ,FFF,H,JJJ,LLL error
```

## Key Menu Options

- **c**: New child change (creates child of selected commit)
- **a**: New after change (creates sibling after selected commit)
- **b**: New before change (inserts before selected commit)
- **m**: New merge change (creates merge commit with multiple parents)
- **s**: New simple change (creates new change without parent specification)

## Command Variations

- **Child**: `jj new <parent_change_id>`
- **After**: `jj new --after <reference_change_id>`
- **Before**: `jj new --before <reference_change_id>`
- **Merge**: `jj new <parent1_change_id> <parent2_change_id> ...`
- **Simple**: `jj new`
- **With Message**: Any of the above with `--message "description"`

## Advanced Features

- **Multi-Parent Support**: Select multiple parents for merge commits
- **Optional Descriptions**: Prompt for commit message
- **Change ID Return**: Returns new change ID for further operations
- **Graph Updates**: Automatically refreshes and highlights new commit

## File Locations

- **Core**: `lua/jj-nvim/jj/new.lua`
- **Actions**: `lua/jj-nvim/jj/actions.lua:534-540`
- **Action Menu**: `lua/jj-nvim/ui/action_menu.lua:139-143`
- **Keybindings**: `n` for new child, `N` for new menu